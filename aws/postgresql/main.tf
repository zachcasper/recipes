terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type = any
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name                 = "postgresql"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "postgresql" {
  name       = "mysql"
  subnet_ids = module.vpc.public_subnets
}

resource "aws_security_group" "rds" {
  name   = "mysql"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_db_instance" "postgres" {
  identifier             = "postgres"
  instance_class         = "db.m7i.large"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14"
  username               = "postgresql_user"
  password               = "WU9VUl9QQVNTV09SRA=="
  db_subnet_group_name   = aws_db_subnet_group.postgresql.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = "default.postgres14"
  publicly_accessible    = true
  skip_final_snapshot    = true
}

output "result" {
  value = {
    values = {
      host = aws_db_instance.postgres.address
      port = aws_db_instance.postgres.port
      database = aws_db_instance.postgres.db_name
      username = aws_db_instance.postgres.username
      password = "WU9VUl9QQVNTV09SRA=="
    }
  }
}
