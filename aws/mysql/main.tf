terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
    region     = "us-east-2"
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type = any
}


resource "aws_db_instance" "mysql" {
  engine               = "mysql"
  identifier           = var.context.application.name
  allocated_storage    = 20
  engine_version       = "8.0"
  instance_class       = "db.t3.small"
  username             = var.context.application.name
  password             = "WU9VUl9QQVNTV09SRA=="
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible =  true
}


output "result" {
  value = {
    values = {
      host = aws_db_instance.mysql.address
      port = aws_db_instance.mysql.port
      database = aws_db_instance.mysql.db_name
      username = aws_db_instance.mysql.username
      password = "WU9VUl9QQVNTV09SRA=="
    }
  }
}