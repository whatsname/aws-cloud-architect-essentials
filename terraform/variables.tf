variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix used for naming all resources"
  type        = string
  default     = "netflux"
}

variable "rds_master_password" {
  description = "RDS master password. Set via TF_VAR_rds_master_password env var or terraform.tfvars (gitignored) — never commit it."
  type        = string
  sensitive   = true
}
