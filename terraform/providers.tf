terraform {
  required_version = ">= 1.7.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # TODO: Configurar backend remoto (Terraform Cloud o S3)
  # backend "s3" {
  #   bucket = "homelab-tfstate"
  #   key    = "homelab/terraform.tfstate"
  #   region = "eu-west-1"
  # }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
