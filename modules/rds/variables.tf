# environnement de déploiement
variable "namespace" {
  type = string
}
variable "environment" {
  type    = string
  default = "dev"
}
# VPC
variable "vpc" {
  type = any
}


# db isntance name
variable "db_instance_name" {
  type = string
}

# db user
variable "db_user" {
  type = string
}

# db pwd
variable "db_pwd" {
  type = string
}

