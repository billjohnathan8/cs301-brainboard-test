#--------------------------------------------------------------
# ECR Module
# Elastic Container Registry for backend service Docker images.
#--------------------------------------------------------------

locals {
  default_repository_names = {
    user        = var.ecr_repository_name != "" ? "${var.ecr_repository_name}-user" : "${var.name_prefix}-user"
    client      = var.ecr_repository_name != "" ? "${var.ecr_repository_name}-client" : "${var.name_prefix}-client"
    transaction = var.ecr_repository_name != "" ? "${var.ecr_repository_name}-transaction" : "${var.name_prefix}-transaction"
  }

  repository_names = merge(local.default_repository_names, var.ecr_repository_names)
}

resource "aws_ecr_repository" "service" {
  for_each = local.repository_names

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each = aws_ecr_repository.service

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain latest 100 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 100
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
