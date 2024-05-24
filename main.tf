terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

/*
terraform {
  backend "s3" {
    bucket = "remote-state-app"
    region = "var.region"
    key    = "eks/terraform.tfstate"
  }
}
*/

provider "aws" {
  region     = var.region
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name      = "servicesweb-eks-${random_string.suffix.result}"
  ebs_csi_irsa_role = module.ebs_csi_irsa_role.iam_role_arn
  tags = {
    Name        = "EKS servicesweb"
    Terraform   = "true"
    Author      = "cviot"
    Environment = "dev"
    Module      = "eks"
  }
}


resource "random_string" "suffix" {
  length  = 8
  special = false
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "servicesweb-vpc"

  cidr = var.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets         = var.private_subnets
  public_subnets          = var.public_subnets
  create_igw              = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "label" = "pub sub"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "label" = "priv sub"
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.cluster_name
  }


}

/*
data "aws_iam_policy_document" "kms_policy_document" {
  statement {
    sid = "Enable IAM User Permissions 2"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::992222228210:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}*/




module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name              = local.cluster_name
  cluster_version           = var.eks_version
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  create_iam_role = true

  enable_irsa = true

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources (Karpenter) into the cluster
  kms_key_enable_default_policy            = false
  create_kms_key                           = false
  cluster_encryption_config                = {}
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = var.eks_params.cluster_endpoint_public_access
  cluster_endpoint_private_access          = var.eks_params.cluster_endpoint_private_access
  //create_kms_key                           = false
  //kms_key_policy = 

  cluster_addons = {
    aws-ebs-csi-driver = {
      addon_version            = "v1.31.0-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = local.ebs_csi_irsa_role
    }   /*
    kube-proxy = {
      most_recent = true
    }
    coredns                = {}
    eks-pod-identity-agent = {}
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }  */           
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  //control_plane_subnet_ids      = module.vpc.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type                   = "AL2_x86_64"
    instance_types             = ["t3.small"]
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    karpenter = {
      instance_types = ["t3.small"]
      iam_role_attach_cni_policy = true
      min_size     = 2
      max_size     = 3
      desired_size = 2

      /*taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"   
        },
      }*/   
    }
  }

  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.cluster_name
  })

  cluster_timeouts = {
    create = "10m"
    update = "10m"
    delete = "20m"
  }

  //depends_on = [  ]

}

module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

/*
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}*/



################################################################################
# Karpenter
################################################################################
/*module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name

  enable_pod_identity             = true
  create_pod_identity_association = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  #create_iam_role      = false
  #iam_role_arn         = module.eks.eks_managed_node_groups["default"].iam_role_arn
  #irsa_use_name_prefix = false

  tags = local.tags
}*/

/*
module "karpenter_disabled" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  create = false
}
*/


################################################################################
# RDS
################################################################################
module "rds" {
  source           = "./modules/rds"
  namespace        = var.namespace
  environment      = var.environment
  db_pwd           = var.MYSQL_DB_PWD
  db_user          = var.MYSQL_DB_USER
  db_instance_name = var.db_instance_name
  vpc              = module.vpc
}

