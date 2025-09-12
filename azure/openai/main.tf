terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
  }
}

variable "model_url" {
  default = "https://huggingface.co/ggml-org/models/resolve/main/tinyllama-1.1b/ggml-model-f16.gguf"
}

variable "model_file_name" {
  default = "ggml-model-f16.gguf"
}

variable "location" {
  type    = string
}

variable "resource_group_name" {
  type = string
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type = any
}

locals {
   uniqueName = var.context.resource.name
}

resource "azurerm_cognitive_account" "openai" {
  count = var.context.resource.properties.model == "gpt35" ? 1 : 0
  name                = local.uniqueName
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = "S0"
}

resource "azurerm_cognitive_deployment" "gpt35" {
    count = var.context.resource.properties.model == "gpt35" ? 1 : 0
    name = var.context.resource.properties.model
    cognitive_account_id = azurerm_cognitive_account.openai.id
    model {
        format = "OpenAI"
        name = var.context.resource.properties.model
        version= "0125"
      }
    rai_policy_name        = "Microsoft.Default"
    version_upgrade_option = "OnceNewDefaultVersionAvailable"  
    sku {
      name     = "Standard"
      capacity = "10"
    }
  }

resource "kubernetes_deployment" "llama" {
  count = var.context.resource.properties.model == "tinyllama" ? 1 : 0

  metadata {
    name      = "llama"
    namespace = var.context.runtime.kubernetes.namespace
    labels = {
      app = "llama"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "llama"
      }
    }

    template {
      metadata {
        labels = {
          app = "llama"
        }
      }

      spec {
        init_container {
          name  = "download-model"
          image = "curlimages/curl:latest"
          command = ["sh", "-c"]
          args = [
            "curl -L --fail --show-error --progress-bar ${var.model_url} -o /models/${var.model_file_name} && ls -la /models/"
          ]

          volume_mount {
            mount_path = "/models"
            name       = "model-volume"
          }
        }

        container {
          name  = "llama"
          image = "ghcr.io/ggerganov/llama.cpp:server"

          port {
            container_port = 8080
          }

          command = ["/app/llama-server"]
          args    = [
            "--model", "/models/${var.model_file_name}", 
            "--host", "0.0.0.0", 
            "--port", "8080",
            "--ctx-size", "512",           # Smaller context for speed
            "--n-predict", "50",           # Match max_tokens from frontend
            "--threads", "4",              # Optimize thread usage
          ]

          volume_mount {
            mount_path = "/models"
            name       = "model-volume"
          }

          resources {
            requests = {
              memory = "6Gi"              # Increased from 4Gi
              cpu    = "2000m"            # Increased from 1000m
            }
            limits = {
              memory = "12Gi"             # Increased from 8Gi
              cpu    = "6000m"            # Increased from 4000m
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 120
            period_seconds = 30
            timeout_seconds = 10
            failure_threshold = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 60
            period_seconds = 10
            timeout_seconds = 5
            failure_threshold = 3
          }
        }

        volume {
          name = "model-volume"
          empty_dir {
            size_limit = "10Gi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "llama" {
  count = var.context.resource.properties.model == "tinyllama" ? 1 : 0
  metadata {
    name      = "llama-service"
    namespace = var.context.runtime.kubernetes.namespace
  }

  spec {
    selector = {
      app = "llama"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

output "result" {
  value = var.context.resource.properties.model == "tinyllama" ? {
    values = {
      endpoint = "http://${kubernetes_service.llama.metadata[0].name}.${kubernetes_service.llama.metadata[0].namespace}.svc.cluster.local:80"
    } 
  } : value = value = var.context.resource.properties.model == "gpt35" ? {
    values = {
      apiVersion = "2023-05-15"
      endpoint   = azurerm_cognitive_account.openai.endpoint
      model = var.context.resource.properties.model
    }
    # Warning: sensitive output
    secrets = {
      apiKey = azurerm_cognitive_account.openai.primary_access_key
    }
    sensitive = true
  } : null
}