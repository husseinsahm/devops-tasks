########################
# في أعلى الملف تقريبًا
########################
locals {
  cluster_name = "${var.project_name}-${var.env}-cluster"
}

################################
# aws_subnet.public (عدّل tags)
################################
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                               = "${var.project_name}-${var.env}-public-${count.index + 1}"
    Environment                        = var.env
    # Tags مهمة لـ EKS
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
}

#################################
# aws_subnet.private (عدّل tags)
#################################
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                               = "${var.project_name}-${var.env}-private-${count.index + 1}"
    Environment                        = var.env
    # Tags مهمة لـ EKS
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}
