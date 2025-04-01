variable "context" {
  description = "This variable contains Radius recipe context."

  type = any
}

variable "node_type" {
  type    = string
  default = "db.t4g.small"
}

variable "num_shards" {
  type        = number
  default = 1
}

variable "num_replicas_per_shard" {
  type = number
  default = 0
}

variable "acl_name" {
  type        = string
  default = "open-access"
}

variable "sku_name" {
  type        = string
  description = "The type of Redis cache to deploy. Valid values: (Basic, Standard, Premium)"
  default     = "Basic"
}
