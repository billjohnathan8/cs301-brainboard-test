#--------------------------------------------------------------
# ECR Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "ecr_repository_name" {
  description = "Optional base ECR repository name. When set, service repositories are created as <base>-<service>."
  type        = string
  default     = ""
}

variable "ecr_repository_names" {
  description = "Optional explicit ECR repository names keyed by service (user, client, transaction)."
  type        = map(string)
  default     = {}
}
