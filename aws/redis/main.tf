terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82"
    }
  }
}

module "memory_db" {
  source = "terraform-aws-modules/memory-db/aws"

  # Cluster
  name = var.context.resource.name
  acl_name = "open-access"
  node_type = "db.t4g.small"
}


