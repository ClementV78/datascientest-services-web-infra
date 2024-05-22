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
/*
# db instance name
variable "wordpress_db" {
  type    = string
  default = "wordpress"
}*/