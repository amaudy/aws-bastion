variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "devbox"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair to use for the bastion host"
  type        = string
} 