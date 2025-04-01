terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}


variable "context" {
  description = "Radius-provided object containing information about the resource calling the Recipe."
  type = any
}

variable "image" {
  description = "Container image name"
  type = string
}

variable "cpuRequest" {
  description = "Minimum number of vCPUs in integers"
  type = number
}

variable "memoryRequest" {
  description = "Minimum amount of memory in mebibyte or gibibytes"
  type = string
}

variable "containerPort" {
  description = "Port application is listening on"
  type = number
}


resource "kubernetes_deployment" "webservice" {
  metadata {
    name = "${var.context.resource.name}-${sha512(var.context.resource.id)}"
    namespace = var.context.runtime.kubernetes.namespace
    labels = {
      app = var.context.application.name
    }
  }
  spec {
    selector {
      match_labels = {
        app = var.context.application.name
        resource = var.context.resource.name
      }
    }
    template {
      metadata {
        labels = {
          app = var.context.application.name
          resource = var.context.resource.name
        }
      }
      spec {
        container {
          name = var.context.resource.name
          image = var.image
          port {
            container_port = var.containerPort
          }
          resources {
            requests = {
              cpu    = var.cpuRequest
              memory = var.memoryRequest
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "webservice" {
  metadata {
    name = "${var.context.resource.name}-${sha512(var.context.resource.id)}"
    namespace = var.context.runtime.kubernetes.namespace
    labels:
      app = var.context.application.name
      service = var.context.application.name
      service: details
  }
  spec {
    type = "ClusterIP"
    selector = {
      app = var.context.application.name
      resource = var.context.resource.name
    }
    port {
      port = "9080"
      name = "http"
    }
  }
}
