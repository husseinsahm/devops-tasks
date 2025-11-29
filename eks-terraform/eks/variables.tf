variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}
