############################################################
# ROOT VARIABLES
############################################################

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "env" {
  type        = string
  description = "Deployment environment (test or prod)"
}

############################################################
# VPC VARIABLES
############################################################

variable "vpc_cidr" {
  type        = string
  description = "CIDR range for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDRs for public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDRs for private subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs to place subnets"
}

############################################################
# EKS VARIABLES
############################################################

# Only needed to pass into EKS module
# private_subnet_ids will be received from VPC module outputs
