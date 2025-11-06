terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type        = any
}

locals {
  uniqueName = var.context.resource.name
  port       = 6379
  namespace  = var.context.runtime.kubernetes.namespace
}

# Generate a secure random password
resource "random_password" "password" {
  length  = 16
  special = false
}

resource "kubernetes_deployment" "redis" {
  metadata {
    name      = local.uniqueName
    namespace = local.namespace
  }

  spec {
    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:7-alpine"

          # Redis authentication (requirepass)
          command = [
            "redis-server",
            "--requirepass", random_password.password.result,
            "--protected-mode", "no"
          ]

          port {
            container_port = local.port
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name      = local.uniqueName
    namespace = local.namespace
  }

  spec {
    selector = {
      app = "redis"
    }

    port {
      port        = local.port
      target_port = local.port
    }
  }
}

output "result" {
  value = {
    values = {
      host     = "${kubernetes_service.redis.metadata[0].name}.${kubernetes_service.redis.metadata[0].namespace}.svc.cluster.local"
      port     = local.port
      password = random_password.password.result
    }
  }
}
