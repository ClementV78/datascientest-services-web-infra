output "wordpress_db_enpoint" {
  value = aws_db_instance.wordpress_db.endpoint
}
output "sg_rds_id" {
  value = aws_security_group.sg_rds.id
}