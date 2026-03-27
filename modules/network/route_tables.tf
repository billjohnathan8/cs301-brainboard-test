#--------------------------------------------------------------
# Network Module - Route Tables
# This file defines route tables and their associations with subnets
# Controls traffic routing for public, private, and database tiers
#--------------------------------------------------------------

# Public route table - routes traffic to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

# Private route table - routes traffic through NAT Gateway
# When enable_multi_az_nat is false, creates a single route table for all private subnets
resource "aws_route_table" "private" {
  count = (!var.enable_multi_az_nat && var.enable_nat_gateway) ? 1 : 0

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[0].id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

# Private route tables (multi-AZ) - one per AZ for high availability
# When enable_multi_az_nat is true, creates one route table per AZ
resource "aws_route_table" "private_per_az" {
  count = (var.enable_multi_az_nat && var.enable_nat_gateway) ? var.az_count : 0

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt-${count.index}"
  }
}

# Database route table - isolated routing for database tier
resource "aws_route_table" "db" {
  count = length(var.db_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-db-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route table
# When enable_multi_az_nat is false, all private subnets use the single route table
resource "aws_route_table_association" "private" {
  for_each = (!var.enable_multi_az_nat && var.enable_nat_gateway) ? aws_subnet.private : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[0].id
}

# Associate private subnets with per-AZ route tables
# When enable_multi_az_nat is true, each private subnet uses its AZ-specific route table
resource "aws_route_table_association" "private_per_az" {
  for_each = (var.enable_multi_az_nat && var.enable_nat_gateway) ? aws_subnet.private : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_per_az[tonumber(each.key)].id
}

# Associate database subnets with database route table
resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db[0].id
}
