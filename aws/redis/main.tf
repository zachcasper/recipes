terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# --- Variables ---

variable "context" {
  description = "Context variable set by Radius which includes the Radius Application, Environment, and other Radius properties"
  type = any
}


variable "num_shards" {
  default = 1
}

variable "num_replicas_per_shard" {
  default = 0
}

# --- Node type mapping ---
locals {
  node_type_map = {
    S = "db.t4g.small"
    M = "db.t4g.medium"
    L = "db.t4g.large"
  }
  capacity = var.context.resource.properties.capacity
  node_type = lookup(local.node_type_map, local.capacity, "db.t4g.small")
}

# --- Random ID for uniqueness ---
resource "random_id" "resource" {
  byte_length = 4
}

resource "random_password" "user_password" {
  length  = 16
  special = false
}

# --- Networking ---
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { user = "zachcasper" }
}

resource "aws_subnet" "subnet_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  tags = { user = "zachcasper" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  tags = { user = "zachcasper" }
}

resource "aws_memorydb_subnet_group" "subnet_group" {
  name       = "memdb-subnets"
  subnet_ids = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id
  ]
  tags = { user = "zachcasper" }
}

# --- MemoryDB User and ACL ---
resource "aws_memorydb_user" "redis_user" {
  user_name     = "appuser"
  access_string = "on ~* +@all"

  authentication_mode {
    type      = "password"
    passwords = [random_password.user_password.result]
  }

  tags = { user = "zachcasper" }
}

resource "aws_memorydb_acl" "redis_acl" {
  name       = "acl-${random_id.resource.hex}"
  user_names = [aws_memorydb_user.redis_user.user_name]
  tags       = { user = "zachcasper" }
}

# --- MemoryDB Cluster ---
resource "aws_memorydb_cluster" "memorydb_cluster" {
  name                   = "memdb-${random_id.resource.hex}"
  node_type              = local.node_type
  num_shards             = var.num_shards
  num_replicas_per_shard = var.num_replicas_per_shard
  acl_name               = aws_memorydb_acl.redis_acl.name
  subnet_group_name      = aws_memorydb_subnet_group.subnet_group.name
  tags                   = { user = "zachcasper" }
}

# --- Bastion Host for SSM Tunnel ---
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg-${random_id.resource.hex}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { user = "zachcasper" }
}

resource "aws_iam_role" "bastion_role" {
  name = "bastion-role-${random_id.resource.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { user = "zachcasper" }
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-profile-${random_id.resource.hex}"
  role = aws_iam_role.bastion_role.name
  tags = { user = "zachcasper" }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  tags = { user = "zachcasper" }
}

# --- Outputs ---
output "host" {
  value       = aws_memorydb_cluster.memorydb_cluster.cluster_endpoint_address
  description = "MemoryDB hostname"
}

output "port" {
  value       = aws_memorydb_cluster.memorydb_cluster.port
  description = "MemoryDB port"
}

output "tls_enabled" {
  value       = true
  description = "MemoryDB enforces TLS"
}

output "username" {
  value       = aws_memorydb_user.redis_user.user_name
  description = "MemoryDB username"
}

output "password" {
  value       = random_password.user_password.result
  description = "MemoryDB password"
  sensitive   = true
}

output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "EC2 instance ID used for SSM tunneling"
}

output "tunnel_instructions" {
  value = <<EOT
To connect from your laptop:

aws ssm start-session \
  --target $(terraform output -raw bastion_instance_id) \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["$(terraform output -raw host)"],"portNumber":["6379"],"localPortNumber":["6379"]}'

Then connect locally:
  redis-cli -h localhost -p 6379 -u rediss://<username>:<password>@localhost:6379
EOT
}
