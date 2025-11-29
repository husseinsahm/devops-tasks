############################################################
# PROVIDER CONFIGURATION
# Loads the AWS provider and uses the region from variables.tf
############################################################
provider "aws" {
  region = var.aws_region
}

############################################################
# VPC SETUP
# Creates the main VPC using variable for CIDR
############################################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.env}-vpc"
    Environment = var.env
  }
}

############################################################
# INTERNET GATEWAY
# Required to give public subnets access to the internet
############################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.env}-igw"
  }
}

############################################################
# PUBLIC SUBNETS
# Dynamically created using variables for CIDRs & AZs
############################################################
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.env}-public-${count.index + 1}"
  }
}

############################################################
# PRIVATE SUBNETS
# Also created dynamically using variable lists
############################################################
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.env}-private-${count.index + 1}"
  }
}

############################################################
# PUBLIC ROUTE TABLE
############################################################
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-${var.env}-public-rt"
  }
}

# Associate public subnets with the public RT
resource "aws_route_table_association" "public_assoc" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

############################################################
# NAT GATEWAY + EIP
# Gives internet access TO PRIVATE subnets
############################################################
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.env}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_name}-${var.env}-nat"
  }
}

############################################################
# PRIVATE ROUTE TABLE → 0.0.0.0/0 goes to NAT
############################################################
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-${var.env}-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

############################################################
# SECURITY GROUPS
############################################################

# Public EC2 SG → Internet access
resource "aws_security_group" "public_sg" {
  name   = "${var.project_name}-${var.env}-public-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Internal EC2 SG → Only inside VPC
resource "aws_security_group" "private_sg" {
  name   = "${var.project_name}-${var.env}-private-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################################
# AMI LOOKUP
############################################################
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

############################################################
# PRIVATE EC2 INSTANCES (BACKEND)
############################################################
resource "aws_instance" "private" {
  count = 2

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  depends_on = [aws_nat_gateway.nat]

  user_data = <<EOF
#!/bin/bash
apt update -y
apt install -y nginx

PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

echo "<h1>Private Server ${count.index + 1}</h1>" > /var/www/html/index.html
echo "<p>Private IP: $PRIVATE_IP</p>" >> /var/www/html/index.html

systemctl restart nginx
EOF

  tags = {
    Name = "${var.project_name}-${var.env}-private-${count.index + 1}"
  }
}


############################################################
# INTERNAL CLASSIC LOAD BALANCER
############################################################
resource "aws_elb" "internal" {
  name     = "${var.project_name}-${var.env}-internal-lb"
  internal = true

  subnets         = aws_subnet.private[*].id
  security_groups = [aws_security_group.private_sg.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  instances = aws_instance.private[*].id
}

############################################################
# PUBLIC EC2 INSTANCES (REVERSE PROXY)
############################################################
resource "aws_instance" "public" {
  count = 2

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]

  depends_on = [aws_elb.internal]

  user_data = <<EOF
#!/bin/bash
apt update -y
apt install -y nginx

cat <<CONFIG > /etc/nginx/sites-available/default
server {
  listen 80;
  location / {
    proxy_pass http://${aws_elb.internal.dns_name};
  }
}
CONFIG

systemctl restart nginx
EOF

  tags = {
    Name = "${var.project_name}-${var.env}-public-${count.index + 1}"
  }
}

############################################################
# PUBLIC CLASSIC LOAD BALANCER
############################################################
resource "aws_elb" "public" {
  name            = "${var.project_name}-${var.env}-public-lb"
  subnets         = aws_subnet.public[*].id
  security_groups = [aws_security_group.public_sg.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  instances = aws_instance.public[*].id
}

