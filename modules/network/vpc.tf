#--------------------------------------------------------------
# Network Module - VPC Core Infrastructure
# This file defines the Virtual Private Cloud and core networking
# components including Internet Gateway and NAT Gateway
#--------------------------------------------------------------

# Primary VPC with DNS support enabled
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Internet Gateway for public subnet connectivity
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Elastic IP for NAT Gateway
# When enable_multi_az_nat is true, creates one EIP per AZ
# When false, creates a single EIP for the primary NAT Gateway
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.enable_multi_az_nat ? var.az_count : 1) : 0

  domain = "vpc"

  tags = {
    Name = var.enable_multi_az_nat ? "${var.name_prefix}-nat-eip-${count.index}" : "${var.name_prefix}-nat-eip"
  }
}

# NAT Gateway for private subnet outbound connectivity
# When enable_multi_az_nat is true, creates one NAT Gateway per AZ for high availability
# When false, creates a single NAT Gateway in the first public subnet (cost-optimized)
resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? (var.enable_multi_az_nat ? var.az_count : 1) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[tostring(count.index)].id

  tags = {
    Name = var.enable_multi_az_nat ? "${var.name_prefix}-nat-${count.index}" : "${var.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}
