terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.0"
    }
  }
}

resource "random_id" "resource" {
  keepers = {
    # Generate a new id for every unique resource id
    resource_id = var.context.resource.id
  }

  byte_length = 8
}

resource "aws_memorydb_cluster" "memorydb_cluster" {
  name                   = "memdb-${random_id.resource.hex}"
  node_type              = var.node_type
  num_shards             = var.num_shards
  num_replicas_per_shard = var.num_replicas_per_shard
  
  acl_name = var.acl_name

  subnet_group_name  = aws_memorydb_subnet_group.test_subnet_group.name
}

resource "aws_vpc" "test_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "test_subnet" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_memorydb_subnet_group" "test_subnet_group" {
  name       = "sg-${random_id.resource.hex}"
  subnet_ids = [aws_subnet.test_subnet.id]
}
