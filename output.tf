output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}
output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}
/*
output "subdomain_zoneid" {
  value = aws_route53_zone.my_subdomain.zone_id
}*/

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "wordpress_db_enpoint" {
  value = module.rds.wordpress_db_enpoint
}

output "db_name" {
  value = var.db_instance_name
}

output "db_username" {
  value = var.MYSQL_DB_USER
}

output "db_password" {
  value = var.MYSQL_DB_PWD
}