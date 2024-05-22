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


output "lb_ip" {
  //value = kubernetes_service.wordpress.spec.load_balancer_ingress[0].hostname
  value = kubernetes_service.wordpress.status.0.load_balancer.0.ingress.0.hostname
  //load_balancer_ingress[0].hostname
}