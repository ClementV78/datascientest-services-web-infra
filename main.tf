terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
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
  cluster_name = "servicesweb-eks-${random_string.suffix.result}"
}
resource "random_string" "suffix" {
  length  = 8
  special = false
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "servicesweb-vpc"

  cidr = "10.3.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets      = ["10.3.10.0/24", "10.3.11.0/24"]
  public_subnets       = ["10.3.20.0/24", "10.3.21.0/24"]
  create_igw           = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_iam_role" "eks-iam-role" {
  name = "servicesweb-eks-iam-role"

  path = "/"
  tags = {
    Terraform   = "true"
    Author      = "cviot"
    Environment = "EKS TEST"
  }
  assume_role_policy = <<EOF
{
 "Version" : "2012-10-17",
 "Statement" : [
  {
   "Effect" : "Allow",
   "Principal" : {
    "Service" : "eks.amazonaws.com"
   },
   "Action": "sts:AssumeRole"
  }
 ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-iam-role.name

}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-iam-role.name
}

resource "aws_eks_cluster" "servicesweb-eks" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks-iam-role.arn

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.all_worker_mgmt.id]
  }


  depends_on = [
    aws_iam_role.eks-iam-role,
  ]
  tags = {
    Terraform   = "true"
    Author      = "cviot"
    Environment = "EKS TEST"
  }
}

resource "aws_iam_role" "workernodes" {
  name = "eks-node-group-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  tags = {
    Terraform   = "true"
    Author      = "cviot"
    Environment = "EKS TEST"
  }
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workernodes.name
}

/***********************************
* Data Source aws_ami pour sélectionner l'ami eks optimized de la région
***********************************/
/*
data "aws_ami" "eks_optimized" {
  most_recent = true
  owners      = ["amazon"]
  //owners      = ["602401143452"] # Amazon EKS Optimized AMI Owner ID

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.28-*"]
  }
}

resource "aws_launch_template" "eks" {
  name_prefix   = "eks-launch-template"
  image_id = data.aws_ami.amazon-linux-2.id
  #image_id      = data.aws_ami.eks.id
  instance_type = "t3.small"

  user_data = base64encode(<<-EOF
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="
    --==MYBOUNDARY==
    Content-Type: text/x-shellscript; charset="us-ascii"
    #!/bin/bash
    /etc/eks/bootstrap.sh your-eks-cluster
    yum update -y
    yum install -y mysql
    --==MYBOUNDARY==--\
      EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "eks-node"
    }
  }
}
*/

resource "aws_eks_node_group" "worker-node-group" {
  cluster_name    = aws_eks_cluster.servicesweb-eks.name
  node_group_name = "servicesweb-workernodes"
  node_role_arn   = aws_iam_role.workernodes.arn
  subnet_ids      = module.vpc.private_subnets

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  
  instance_types  = ["t3.small"]
  /*launch_template {
    id        = aws_launch_template.eks.id
    version   = aws_launch_template.eks.latest_version
  }*/
  
  remote_access {
    ec2_ssh_key               = var.key_name
    source_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Terraform   = "true"
    Author      = "cviot"
    Environment = "EKS TEST"
  }
}

data "aws_eks_addon_version" "this" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.servicesweb-eks.version
  most_recent        = true
}

resource "aws_eks_addon" "this" {

  cluster_name = aws_eks_cluster.servicesweb-eks.name
  addon_name   = "aws-ebs-csi-driver"

  addon_version               = data.aws_eks_addon_version.this.version
  configuration_values        = null
  preserve                    = true
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = null

  depends_on = [
    aws_eks_node_group.worker-node-group
  ]

}

resource "aws_iam_role_policy_attachment" "storage" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.workernodes.name
}

module "rds" {
  source           = "./modules/rds"
  namespace        = var.namespace
  environment      = var.environment
  db_pwd           = var.MYSQL_DB_PWD
  db_user          = var.MYSQL_DB_USER
  db_instance_name = var.db_instance_name
  vpc              = module.vpc
}

