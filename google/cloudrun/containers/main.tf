terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      #  version = "~> 5.0" # Specify a version constraint
    }
  }
}

variable "gcp_service_account_key" {
  description = "The content of the Google Service Account key file in JSON format."
  type        = string
  #  sensitive   = true
}

provider "google" {
  project     = "radius-cloud-run"
  region      = var.region
  credentials = var.gcp_service_account_key
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type = any
}

variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

module "service_account" {
  source     = "terraform-google-modules/service-accounts/google"
  version    = "~> 4.2"
  project_id = var.project_id
  prefix     = "sa-cloud-run"
  names      = ["simple"]
}

module "cloud_run" {
  source  = "GoogleCloudPlatform/cloud-run/google"
  version = "~> 0.16"

  service_name          = "ci-cloud-run"
  project_id            = var.project_id
  location              = var.region
  image                 = var.context.resource.properties.container.image
  ports = {
    name = var.context.resource.properties.container.web
    port = var.context.resource.properties.container.web.containerPort
  }
  service_account_email = module.service_account.email
}

output "service_name" {
  value       = module.cloud_run.service_name
  description = "Name of the created service"
}

output "revision" {
  value       = module.cloud_run.revision
  description = "Deployed revision for the service"
}

output "service_url" {
  value       = module.cloud_run.service_url
  description = "The URL on which the deployed service is available"
}

output "service_id" {
  value       = module.cloud_run.service_id
  description = "Unique Identifier for the created service"
}

output "service_status" {
  value       = module.cloud_run.service_status
  description = "Status of the created service"
}

output "service_location" {
  value       = module.cloud_run.location
  description = "Location in which the Cloud Run service was created"
}
