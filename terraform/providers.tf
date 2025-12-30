terraform {
  required_version = ">= 1.5.0"

  # Declare the required provider plugins
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS using the variable for your named profile
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile 
}

# Configure GCP using the project ID variable
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
