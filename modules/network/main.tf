#--------------------------------------------------------------
# Network Module - Data Sources and Local Variables
# This file contains data source queries and computed locals
# used across the network module
#--------------------------------------------------------------

# Query available AWS Availability Zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# Local variables for subnet and AZ management
locals {
  # Select the number of AZs specified by var.az_count
  selected_azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Create subnet maps for for_each iteration
  public_subnet_map  = { for idx, cidr in var.public_subnet_cidrs : tostring(idx) => cidr }
  private_subnet_map = { for idx, cidr in var.private_subnet_cidrs : tostring(idx) => cidr }
  db_subnet_map      = { for idx, cidr in var.db_subnet_cidrs : tostring(idx) => cidr }
}
