#--------------------------------------------------------------
# Security Module
# Security groups, IAM roles and policies, and Secrets Manager
# entries for ALB, ECS, Lambda, and RDS access control.
#--------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  # When a lab role override is supplied, skip all IAM role creation and use the
  # pre-existing role (for example, LabRole in Learner Lab which blocks iam:CreateRole).
  effective_lab_role_arn = var.lab_role_arn != "" ? var.lab_role_arn : (var.lab_role_name != "" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.lab_role_name}" : "")
  use_lab_role           = local.effective_lab_role_arn != ""
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow inbound HTTP and HTTPS traffic to ALB."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "ecs_service" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "Allow app traffic from ALB and internal ECS traffic."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Backend traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Service-to-service traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ecs-sg"
  }
}

resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda functions in VPC."
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-lambda-sg"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Allow PostgreSQL from ECS services and Lambda."
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS services"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service.id]
  }

  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-db-sg"
  }
}

data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  count              = local.use_lab_role ? 0 : 1
  name               = "${var.name_prefix}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  count      = local.use_lab_role ? 0 : 1
  role       = aws_iam_role.ecs_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution_extra" {
  statement {
    sid     = "ReadSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.jwt_hmac.arn,
      aws_secretsmanager_secret.root_admin_password.arn,
      aws_secretsmanager_secret.db_username.arn,
      aws_secretsmanager_secret.db_password.arn,
    ]
  }

  statement {
    sid    = "ReadSsmParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_extra" {
  count  = local.use_lab_role ? 0 : 1
  name   = "${var.name_prefix}-ecs-task-exec-extra"
  role   = aws_iam_role.ecs_task_execution[0].id
  policy = data.aws_iam_policy_document.ecs_task_execution_extra.json
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task" {
  for_each = local.use_lab_role ? toset([]) : toset(["user", "client", "transaction"])

  name               = "${var.name_prefix}-ecs-task-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "log_lambda" {
  count              = local.use_lab_role ? 0 : 1
  name               = "${var.name_prefix}-log-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "log_lambda_basic" {
  count      = local.use_lab_role ? 0 : 1
  role       = aws_iam_role.log_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "log_lambda_vpc" {
  count      = local.use_lab_role ? 0 : 1
  role       = aws_iam_role.log_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "log_lambda_secrets" {
  statement {
    sid     = "ReadLogSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.jwt_hmac.arn,
      aws_secretsmanager_secret.db_username.arn,
      aws_secretsmanager_secret.db_password.arn,
    ]
  }
}

resource "aws_iam_role_policy" "log_lambda_secrets" {
  count  = local.use_lab_role ? 0 : 1
  name   = "${var.name_prefix}-log-lambda-secrets"
  role   = aws_iam_role.log_lambda[0].id
  policy = data.aws_iam_policy_document.log_lambda_secrets.json
}

resource "aws_iam_role" "aml_lambda" {
  count              = local.use_lab_role ? 0 : 1
  name               = "${var.name_prefix}-aml-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "aml_lambda_basic" {
  count      = local.use_lab_role ? 0 : 1
  role       = aws_iam_role.aml_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "aml_lambda_secrets" {
  statement {
    sid    = "ReadAmlSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = compact([
      var.aml_sftp_key_secret_arn,
      aws_secretsmanager_secret.jwt_hmac.arn,
    ])
  }

  statement {
    sid    = "ReadLogApiUrlParameter"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/service/log/url",
    ]
  }
}

resource "aws_iam_role_policy" "aml_lambda_secrets" {
  count  = local.use_lab_role ? 0 : 1
  name   = "${var.name_prefix}-aml-lambda-secrets"
  role   = aws_iam_role.aml_lambda[0].id
  policy = data.aws_iam_policy_document.aml_lambda_secrets.json
}

# --- Transaction ingestion Lambda role ---

resource "aws_iam_role" "sftp_transaction_collector" {
  count = var.enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  name               = "${var.name_prefix}-sftp-transaction-collector"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "sftp_transaction_collector_basic" {
  count = var.enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.sftp_transaction_collector[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "sftp_transaction_collector_s3" {
  count = var.enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ReadTransactionSftpBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = compact([
      var.transaction_sftp_bucket_arn,
      "${var.transaction_sftp_bucket_arn}/*",
    ])
  }
}

resource "aws_iam_role_policy" "sftp_transaction_collector_s3" {
  count = var.enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-sftp-transaction-collector-s3"
  role   = aws_iam_role.sftp_transaction_collector[0].id
  policy = data.aws_iam_policy_document.sftp_transaction_collector_s3[0].json
}

data "aws_iam_policy_document" "sftp_transaction_collector_secrets" {
  count = var.enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ReadTransactionIngestionJwtSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.jwt_hmac.arn,
    ]
  }
}

resource "aws_iam_role_policy" "sftp_transaction_collector_secrets" {
  count = var.enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-sftp-transaction-collector-secrets"
  role   = aws_iam_role.sftp_transaction_collector[0].id
  policy = data.aws_iam_policy_document.sftp_transaction_collector_secrets[0].json
}

# --- Audit consumer Lambda role ---

resource "aws_iam_role" "audit_consumer_lambda" {
  count = var.enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  name               = "${var.name_prefix}-audit-consumer-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "audit_consumer_lambda_basic" {
  count = var.enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.audit_consumer_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "audit_consumer_lambda_vpc" {
  count = var.enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.audit_consumer_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "audit_consumer_lambda" {
  count = var.enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ConsumeAuditQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = compact([var.audit_sqs_arn, var.audit_dlq_arn])
  }

  statement {
    sid    = "WriteDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [var.audit_dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "audit_consumer_lambda" {
  count = var.enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-audit-consumer-lambda"
  role   = aws_iam_role.audit_consumer_lambda[0].id
  policy = data.aws_iam_policy_document.audit_consumer_lambda[0].json
}

# --- AML consumer Lambda role ---

resource "aws_iam_role" "aml_consumer_lambda" {
  count = var.enable_aml_pipeline && !local.use_lab_role ? 1 : 0

  name               = "${var.name_prefix}-aml-consumer-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "aml_consumer_lambda_basic" {
  count = var.enable_aml_pipeline && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.aml_consumer_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "aml_consumer_lambda" {
  count = var.enable_aml_pipeline && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ConsumeAmlQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = compact([var.aml_sqs_arn, var.aml_dlq_arn])
  }

  statement {
    sid    = "WriteDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [var.aml_dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "aml_consumer_lambda" {
  count = var.enable_aml_pipeline && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-aml-consumer-lambda"
  role   = aws_iam_role.aml_consumer_lambda[0].id
  policy = data.aws_iam_policy_document.aml_consumer_lambda[0].json
}

# --- Verification Lambda role ---

resource "aws_iam_role" "verification_lambda" {
  count = var.enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  name               = "${var.name_prefix}-verification-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "verification_lambda_basic" {
  count = var.enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.verification_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "verification_lambda" {
  count = var.enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ReadVerificationBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.verification_bucket_arn,
      "${var.verification_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "PublishVerificationSns"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [var.verification_sns_topic_arn]
  }

  statement {
    sid    = "ReadVerificationJwtSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [aws_secretsmanager_secret.jwt_hmac.arn]
  }

  statement {
    sid    = "SendVerificationEmailViaSes"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "verification_lambda" {
  count = var.enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-verification-lambda"
  role   = aws_iam_role.verification_lambda[0].id
  policy = data.aws_iam_policy_document.verification_lambda[0].json
}

data "aws_iam_policy_document" "ecs_client_ses_send" {
  count = var.enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "SendVerificationEmailViaSes"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_client_ses_send" {
  count = var.enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-ecs-task-client-ses-send"
  role   = aws_iam_role.ecs_task["client"].id
  policy = data.aws_iam_policy_document.ecs_client_ses_send[0].json
}

data "aws_iam_policy_document" "ecs_client_publish_verification_sns" {
  count = var.enable_verification_pipeline && var.verification_sns_topic_arn != "" && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "PublishVerificationRequestedEvents"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [var.verification_sns_topic_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_client_publish_verification_sns" {
  count = var.enable_verification_pipeline && var.verification_sns_topic_arn != "" && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-ecs-task-client-verification-sns-publish"
  role   = aws_iam_role.ecs_task["client"].id
  policy = data.aws_iam_policy_document.ecs_client_publish_verification_sns[0].json
}

data "aws_iam_policy_document" "ecs_client_write_verification_s3" {
  count = var.enable_verification_pipeline && var.verification_bucket_arn != "" && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "WriteVerificationDocuments"
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = ["${var.verification_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_client_write_verification_s3" {
  count = var.enable_verification_pipeline && var.verification_bucket_arn != "" && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-ecs-task-client-verification-s3-write"
  role   = aws_iam_role.ecs_task["client"].id
  policy = data.aws_iam_policy_document.ecs_client_write_verification_s3[0].json
}

# --- ECS task policy: allow sending to SQS queues ---

data "aws_iam_policy_document" "ecs_sqs_send" {
  count = (var.enable_audit_pipeline || var.enable_aml_pipeline) && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "SendToSqs"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
    ]
    resources = compact([var.audit_sqs_arn, var.aml_sqs_arn])
  }
}

resource "aws_iam_role_policy" "ecs_task_sqs" {
  for_each = (var.enable_audit_pipeline || var.enable_aml_pipeline) && !local.use_lab_role ? toset(["user", "client", "transaction"]) : toset([])

  name   = "${var.name_prefix}-ecs-task-${each.key}-sqs"
  role   = aws_iam_role.ecs_task[each.key].id
  policy = data.aws_iam_policy_document.ecs_sqs_send[0].json
}

data "aws_iam_policy_document" "ecs_transaction_s3_read" {
  count = var.enable_sftp_transaction_collector && var.transaction_sftp_bucket_arn != "" && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ReadTransactionIngestionS3Source"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.transaction_sftp_bucket_arn,
      "${var.transaction_sftp_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_transaction_s3_read" {
  count = var.enable_sftp_transaction_collector && var.transaction_sftp_bucket_arn != "" && !local.use_lab_role ? 1 : 0

  name   = "${var.name_prefix}-ecs-task-transaction-s3-read"
  role   = aws_iam_role.ecs_task["transaction"].id
  policy = data.aws_iam_policy_document.ecs_transaction_s3_read[0].json
}

data "aws_iam_policy_document" "terraform_backend_access" {
  count = var.create_backend_iam_policy ? 1 : 0

  statement {
    sid    = "StateBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.backend_state_bucket_name}",
    ]
  }

  statement {
    sid    = "StateBucketObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.backend_state_bucket_name}/*",
    ]
  }

  statement {
    sid    = "StateLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.backend_lock_table_name}",
    ]
  }
}

resource "aws_iam_policy" "terraform_backend_access" {
  count = var.create_backend_iam_policy ? 1 : 0

  name        = "${var.name_prefix}-terraform-backend-access"
  description = "IAM policy for Terraform S3 backend and DynamoDB lock table access."
  policy      = data.aws_iam_policy_document.terraform_backend_access[0].json
}
