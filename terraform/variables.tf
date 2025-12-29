# variables.tf

variable "gcp_project_id" {
  type        = string
  description = "The GCP Project ID where resources will be deployed"
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "aws_profile" {
  type        = string
  description = "The AWS Named Profile to use (lighthouse-dr)"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "dr_mode_active" {
  type        = bool
  default     = false
  description = "Scale up standby (GCP) resources if true"
}
