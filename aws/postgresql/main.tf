terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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
  name       = "postgres-subnet-group"
  subnet_ids = module.vpc.public_subnets
}

resource "aws_security_group" "rds" {
  name   = "postgres-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# --- Generate a secure password ---
resource "random_password" "db_password" {
  length  = 16
  special = true
}


resource "aws_db_instance" "postgres" {
  identifier             = "postgres"
  instance_class         = "db.m7i.large"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14"
  username               = "postgresql_user"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.postgresql.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = "default.postgres14"
  publicly_accessible    = true
  skip_final_snapshot    = true
}

# --- Create the database after the instance is ready ---
resource "null_resource" "create_db" {
  depends_on = [aws_db_instance.postgres]

  provisioner "local-exec" {
    command = <<EOT
PGPASSWORD="${random_password.db_password.result}" psql \
  -h ${aws_db_instance.postgres.address} \
  -U ${aws_db_instance.postgres.username} \
  -p ${aws_db_instance.postgres.port} \
  -c "CREATE DATABASE postgres_db;"
EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

output "result" {
  value = {
    values = {
      host = aws_db_instance.postgres.address
      port = aws_db_instance.postgres.port
      database = "postgres_db"
      username = aws_db_instance.postgres.username
      password = "WU9VUl9QQVNTV09SRA=="
    }
  }
}
