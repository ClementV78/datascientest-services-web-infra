
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds-subnet-group"
  subnet_ids = var.vpc.private_subnets

  tags = {
    Terraform = "true"
    Author = "cviot"
    Environment = "dev"
    Module = "rds"
    Name = "${var.namespace}-rds-subg"
  }
}

resource "aws_security_group" "sg_rds" {
  name = "sg_rds"
  description = "Autoriser le trafic entrant MySQL depuis le public sunet"
  vpc_id      = var.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc.vpc_cidr_block]
  }

  tags = {
    Terraform = "true"
    Author = "cviot"
    Environment = "${var.environment}"
    Module = "rds"
    Name = "${var.namespace}-sg-rds"
  }
}

resource "aws_db_instance" "wordpress_db" {
  allocated_storage = 5
  storage_type = "gp2"
  engine = "mysql"
  instance_class = "db.t3.micro"
  identifier = "${var.db_instance_name}"
  username = "${var.db_user}"
  password = "${var.db_pwd}"
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  # Enable Multi-AZ deployment for high availability
  multi_az = true

  skip_final_snapshot = true // required to destroy

  tags = {
    Terraform = "true"
    Author = "cviot"
    Environment = "dev"
    Module = "rds"
    Name = "${var.namespace}-rds-mysql"
  }
}
