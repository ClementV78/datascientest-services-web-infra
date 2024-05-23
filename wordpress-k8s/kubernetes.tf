# # Kubernetes provider
# # https://learn.hashicorp.com/terraform/kubernetes/provision-eks-cluster#optional-configure-terraform-kubernetes-provider
# # To learn how to schedule deployments and services using the provider, go here: ttps://learn.hashicorp.com/terraform/kubernetes/deploy-nginx-kubernetes.

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "eks" {
  backend = "local"
  config = {
    path = "../terraform.tfstate"
  }
}

# Retrieve EKS cluster configuration
data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

/*data "aws_eks_cluster_auth" "eks" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}*/

provider "kubernetes" {
  //load_config_file       = "false"
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}


resource "kubernetes_persistent_volume_claim" "wordpress" {
  metadata {
    name = "wp-pv-claim"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    storage_class_name = "gp2"
    //volume_name = kubernetes_persistent_volume.wordpress.metadata[0].name
  }
  wait_until_bound = false
}


resource "kubernetes_deployment" "wordpress" {
  metadata {
    name = "wordpress"
    labels = {
      App = "wordpress"
    }
  }
  timeouts {
    create = "5m"
    update = "5m"
    delete = "10m"
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "wordpress"
      }
    }
    template {
      metadata {
        labels = {
          App = "wordpress"
        }
      }
      spec {
        container {
          image = "clementv78/wordpress-mysql"
          name  = "wordpress"
          env {
            name  = "WORDPRESS_DB_HOST"
            value = data.terraform_remote_state.eks.outputs.wordpress_db_enpoint
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = data.terraform_remote_state.eks.outputs.db_username
          }
          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = data.terraform_remote_state.eks.outputs.db_password
          }
          env {
            name  = "WORDPRESS_DB_DATABASE"
            value = data.terraform_remote_state.eks.outputs.db_name
          }
          env {
            name  = "WORDPRESS_DB_NAME"
            value = var.wordpress_database_name
          }
          port {
            container_port = 80
          }
          volume_mount {
            name       = "wordpress-persistent-storage"
            mount_path = "/var/www/html"
          }
        }
        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wordpress.metadata[0].name
          }
        }
      }
    }
  }
}



resource "kubernetes_service" "wordpress" {
  metadata {
    name = "wordpress"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    selector = {
      App = kubernetes_deployment.wordpress.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

/***********************************
*  Certificat ACM
***********************************/
# SSL Certificate avec validation DNS
resource "aws_acm_certificate" "my_certificate" {
  domain_name       = "servicesweb.0xclem.cloudns.ch"
  validation_method = "DNS"

  tags = {
    Name        = "SSL certificate"
    Terraform   = "true"
    Author      = "cviot"
    Environment = "dev"
    Module      = "acm"
  }
}
/*
resource "aws_route53_record" "wordpress" {
  zone_id = data.terraform_remote_state.eks.outputs.subdomain_zoneid
  name    = "servicesweb.0xclem.cloudns.ch"
  type    = "CNAME"
  ttl     = 300
  records = [kubernetes_service.wordpress.status[0].load_balancer[0].ingress[0].hostname]
}
*/
/***********************************
*  Record Route 53
***********************************/
# DNS validation record
resource "aws_route53_record" "cert_validation" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.my_certificate.domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.my_certificate.domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.my_certificate.domain_validation_options)[0].resource_record_type
  zone_id         = data.terraform_remote_state.eks.outputs.subdomain_zoneid
  ttl             = 60
}

/***********************************
*  Validation certificat ACM
***********************************/
resource "aws_acm_certificate_validation" "my-certificate" {
  certificate_arn         = aws_acm_certificate.my_certificate.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}


## Add data source ## 
data "aws_elb_hosted_zone_id" "this" {}
### This will use your aws provider-level region config otherwise mention explicitly.


/***********************************
*  Enregistrement DNS dans Route 53 pour le Load Balancer
***********************************/
resource "aws_route53_record" "www" {
  zone_id = data.terraform_remote_state.eks.outputs.subdomain_zoneid
  name    = "servicesweb.0xclem.cloudns.ch"
  type    = "A"

  alias {
    name                   = kubernetes_service.wordpress.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_elb_hosted_zone_id.this.id ## Updated ##
    evaluate_target_health = true
  }
}


output "lb_ip" {
  //value = kubernetes_service.wordpress.spec.load_balancer_ingress[0].hostname
  value = kubernetes_service.wordpress.status.0.load_balancer.0.ingress.0.hostname
  //load_balancer_ingress[0].hostname
}