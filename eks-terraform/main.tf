terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Root provider configuration (مطلوب بشدة)
provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  project_name         = var.project_name
  env                  = var.env
}

module "eks" {
  source = "./eks"

  aws_region        = var.aws_region
  project_name      = var.project_name
  env               = var.env

  private_subnet_ids = module.vpc.private_subnet_ids
}

module "jenkins" {
  source = "./jenkins"

  project_name     = var.project_name
  env              = var.env
  public_subnet_id = module.vpc.public_subnet_ids[0]
  vpc_id           = module.vpc.vpc_id
  aws_region       = var.aws_region
}
