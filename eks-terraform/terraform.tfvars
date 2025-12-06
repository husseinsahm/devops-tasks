aws_region            = "eu-west-1"
project_name          = "devops-eks"
env                   = "test"

vpc_cidr              = "10.0.0.0/16"

public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = ["10.0.3.0/24", "10.0.4.0/24"]

availability_zones    = ["eu-west-1a", "eu-west-1b"]
