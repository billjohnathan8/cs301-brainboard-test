#--------------------------------------------------------------
# Network Module - Subnets
# This file defines all subnet resources across multiple
# availability zones for high availability
#--------------------------------------------------------------

# Public subnets for resources that need direct internet access
# (e.g., Application Load Balancers, NAT Gateways)
resource "aws_subnet" "public" {
  for_each = local.public_subnet_map

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = local.selected_azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${tonumber(each.key) + 1}"
    Tier = "public"
  }
}

# Private subnets for application workloads
# (e.g., ECS tasks, Lambda functions)
resource "aws_subnet" "private" {
  for_each = local.private_subnet_map

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = local.selected_azs[tonumber(each.key)]

  tags = {
    Name = "${var.name_prefix}-private-${tonumber(each.key) + 1}"
    Tier = "private"
  }
}

# Dedicated database subnets with isolated routing
# (e.g., RDS instances)
resource "aws_subnet" "db" {
  for_each = local.db_subnet_map

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = local.selected_azs[tonumber(each.key)]

  tags = {
    Name = "${var.name_prefix}-db-${tonumber(each.key) + 1}"
    Tier = "database"
  }
}
