variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}
variable "namespace" {
  description = "L'espace de noms de projet à utiliser pour la dénomination unique des ressources"
  default     = "cviot-eks-tf"
  type        = string
}

# variable pour l'environnement de déploiement
variable "environment" {
  type    = string
  default = "dev"
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}
variable "AWS_ACCESS_KEY_ID" {
  type = string
}
variable "key_name" {
  type    = string
  default = "cviot_keypair"
}

variable "MYSQL_DB_USER" {
  type = string
}

variable "MYSQL_DB_PWD" {
  type = string
}

# db instance name
variable "db_instance_name" {
  type    = string
  default = "mysql-wordpress"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.3.20.0/24", "10.3.21.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.3.10.0/24", "10.3.11.0/24"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.3.0.0/16"
}

variable "eks_params" {
  description = "EKS cluster itslef parameters"
  type = object({
    cluster_endpoint_public_access  = bool
    cluster_endpoint_private_access = bool
    cluster_enabled_log_types       = list(string)
  })
}

variable "eks_version" {
  description = "Kubernetes version, will be used in AWS resources names and to specify which EKS version to create/update"
  type        = string
}

/*variable "kms_policy"{
  type = string
}*/

/*variable "external_dns_zone" {
  type        = string
  description = "AWS Route53 zone to be used by ExternalDNS in domainFilters and its IAM Policy"
}
*/

/*
# db instance name
variable "wordpress_db" {
  type    = string
  default = "wordpress"
}*/