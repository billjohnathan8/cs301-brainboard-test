#--------------------------------------------------------------
# Network Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "az_count" {
  description = "How many Availability Zones to use."
  type        = number
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks for dedicated database subnets. If empty, RDS uses private subnets."
  type        = list(string)
  default     = []
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Retention in days for VPC flow log group."
  type        = number
  default     = 30
}

variable "enable_multi_az_nat" {
  description = "Enable NAT Gateway in each AZ for high availability (increases cost)."
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway resources for private subnet internet egress. Disable for low-cost lab deployments that run ECS tasks in public subnets."
  type        = bool
  default     = true
}
