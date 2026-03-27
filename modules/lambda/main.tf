#--------------------------------------------------------------
# Lambda Module
# Log-service Lambda function with CloudWatch logging,
# DynamoDB access, and API Gateway integration.
#--------------------------------------------------------------

resource "aws_cloudwatch_log_group" "log_lambda" {
  count = var.enable_log_lambda ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-log-service"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_lambda_function" "log" {
  count = var.enable_log_lambda ? 1 : 0

  function_name    = "${var.name_prefix}-log-service"
  filename         = var.log_lambda_zip_path
  source_code_hash = filebase64sha256(var.log_lambda_zip_path)
  role             = var.log_lambda_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.log_lambda_memory_size
  timeout          = var.log_lambda_timeout_seconds
  publish          = true

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_HOST                = var.db_host
      DB_PORT                = tostring(var.db_port)
      DB_NAME                = var.db_name
      DB_USER_SECRET_ARN     = var.db_username_secret_arn
      DB_PASSWORD_SECRET_ARN = var.db_password_secret_arn
      JWT_HMAC_SECRET_ARN    = var.jwt_hmac_secret_arn
      AUTH_MODE              = var.auth_mode
      COGNITO_ISSUER         = var.cognito_issuer_url
      COGNITO_JWKS_URL       = var.cognito_jwks_url
      COGNITO_CLIENT_ID      = var.cognito_audience
    }
  }

  depends_on = [aws_cloudwatch_log_group.log_lambda[0]]
}

resource "aws_cloudwatch_log_group" "aml_lambda" {
  count = var.enable_aml_lambda ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-aml"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_lambda_function" "aml" {
  count = var.enable_aml_lambda ? 1 : 0

  function_name    = "${var.name_prefix}-aml"
  filename         = var.aml_lambda_zip_path
  source_code_hash = filebase64sha256(var.aml_lambda_zip_path)
  role             = var.aml_lambda_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.aml_lambda_memory_size
  timeout          = var.aml_lambda_timeout_seconds
  publish          = true

  environment {
    variables = {
      SFTP_HOST                   = var.aml_sftp_host
      SFTP_PORT                   = tostring(var.aml_sftp_port)
      SFTP_USER                   = var.aml_sftp_user
      SFTP_KEY_SECRET             = var.aml_sftp_key_secret_arn
      SFTP_REMOTE_PATH            = var.aml_sftp_remote_path
      CRM_API_BASE_URL            = var.crm_api_base_url
      CRM_LOG_API_URL_PARAM       = "/${var.project_name}/${var.environment}/service/log/url"
      CRM_API_JWT_HMAC_SECRET_ARN = var.jwt_hmac_secret_arn
      JWT_HMAC_SECRET_ARN         = var.jwt_hmac_secret_arn
      ENTITY_ID                   = var.aml_entity_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.aml_lambda[0]]
}

resource "aws_cloudwatch_event_rule" "aml_schedule" {
  count = var.enable_aml_lambda ? 1 : 0

  name                = "${var.name_prefix}-aml-schedule"
  description         = "Schedule for AML Lambda batch processing."
  schedule_expression = var.aml_schedule_expression
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "aml_lambda" {
  count = var.enable_aml_lambda ? 1 : 0

  rule      = aws_cloudwatch_event_rule.aml_schedule[0].name
  target_id = "aml-lambda"
  arn       = aws_lambda_function.aml[0].arn
  input     = "{}"
}

resource "aws_lambda_permission" "allow_eventbridge_invoke_aml" {
  count = var.enable_aml_lambda ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.aml[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.aml_schedule[0].arn
}

# --- Audit consumer Lambda (SQS → DynamoDB) ---

resource "aws_cloudwatch_log_group" "sftp_transaction_collector" {
  count = var.enable_sftp_transaction_collector ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-sftp-transaction-collector"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_lambda_function" "sftp_transaction_collector" {
  count = var.enable_sftp_transaction_collector ? 1 : 0

  function_name    = "${var.name_prefix}-sftp-transaction-collector"
  filename         = var.sftp_transaction_collector_zip_path
  source_code_hash = filebase64sha256(var.sftp_transaction_collector_zip_path)
  role             = var.sftp_transaction_collector_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.sftp_transaction_collector_memory_size
  timeout          = var.sftp_transaction_collector_timeout_seconds
  publish          = true

  environment {
    variables = {
      # Legacy naming retained for compatibility; bucket/prefix are S3-backed mock ingestion inputs.
      TRANSACTION_SFTP_BUCKET                = var.transaction_sftp_bucket_id
      TRANSACTION_SFTP_PREFIX                = var.transaction_sftp_remote_prefix
      TRANSACTION_IMPORT_URL                 = var.transaction_import_api_url
      TRANSACTION_IMPORT_JWT_HMAC_SECRET_ARN = var.jwt_hmac_secret_arn
      JWT_HMAC_SECRET_ARN                    = var.jwt_hmac_secret_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.sftp_transaction_collector[0]]
}

resource "aws_cloudwatch_event_rule" "sftp_transaction_collector_schedule" {
  count = var.enable_sftp_transaction_collector ? 1 : 0

  name                = "${var.name_prefix}-sftp-transaction-collector-schedule"
  description         = "Schedule for sftp-transaction-collector Lambda."
  schedule_expression = var.sftp_transaction_collector_schedule_expression
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "sftp_transaction_collector" {
  count = var.enable_sftp_transaction_collector ? 1 : 0

  rule      = aws_cloudwatch_event_rule.sftp_transaction_collector_schedule[0].name
  target_id = "sftp-transaction-collector"
  arn       = aws_lambda_function.sftp_transaction_collector[0].arn
  input     = "{}"
}

resource "aws_lambda_permission" "allow_eventbridge_invoke_sftp_transaction_collector" {
  count = var.enable_sftp_transaction_collector ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeTransactionIngestion"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sftp_transaction_collector[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sftp_transaction_collector_schedule[0].arn
}

resource "aws_cloudwatch_log_group" "audit_consumer" {
  count = var.enable_audit_consumer ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-audit-consumer"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_lambda_function" "audit_consumer" {
  count = var.enable_audit_consumer ? 1 : 0

  function_name    = "${var.name_prefix}-audit-consumer"
  filename         = var.audit_consumer_zip_path
  source_code_hash = filebase64sha256(var.audit_consumer_zip_path)
  role             = var.audit_consumer_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.audit_consumer_memory_size
  timeout          = var.audit_consumer_timeout_seconds

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.audit_dynamodb_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.audit_consumer]
}

resource "aws_lambda_event_source_mapping" "audit_sqs" {
  count = var.enable_audit_consumer ? 1 : 0

  event_source_arn        = var.audit_sqs_arn
  function_name           = aws_lambda_function.audit_consumer[0].arn
  batch_size              = 10
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}

# --- AML consumer Lambda (SQS → DynamoDB) ---

resource "aws_cloudwatch_log_group" "aml_consumer" {
  count = var.enable_aml_consumer ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-aml-consumer"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_lambda_function" "aml_consumer" {
  count = var.enable_aml_consumer ? 1 : 0

  function_name    = "${var.name_prefix}-aml-consumer"
  filename         = var.aml_consumer_zip_path
  source_code_hash = filebase64sha256(var.aml_consumer_zip_path)
  role             = var.aml_consumer_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.aml_consumer_memory_size
  timeout          = var.aml_consumer_timeout_seconds

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.aml_dynamodb_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.aml_consumer]
}

resource "aws_lambda_event_source_mapping" "aml_sqs" {
  count = var.enable_aml_consumer ? 1 : 0

  event_source_arn        = var.aml_sqs_arn
  function_name           = aws_lambda_function.aml_consumer[0].arn
  batch_size              = 10
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}

# --- Verification Lambda (S3 → SNS → SES) ---

resource "aws_cloudwatch_log_group" "verification" {
  count = var.enable_verification_lambda ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-verification"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_lambda_function" "verification" {
  count = var.enable_verification_lambda ? 1 : 0

  function_name    = "${var.name_prefix}-verification"
  filename         = var.verification_zip_path
  source_code_hash = filebase64sha256(var.verification_zip_path)
  role             = var.verification_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.verification_memory_size
  timeout          = var.verification_timeout_seconds
  publish          = true

  environment {
    variables = {
      SES_SOURCE_EMAIL                 = var.ses_sender_email
      FRONTEND_BASE_URL                = var.verification_frontend_base_url
      LOG_API_BASE_URL                 = var.log_api_base_url
      VERIFICATION_JWT_HMAC_SECRET_ARN = var.verification_jwt_hmac_secret_arn
      VERIFICATION_JWT_SUB             = "SYSTEM_VERIFICATION_FEEDBACK"
      VERIFICATION_JWT_ROLE            = "admin"
    }
  }

  depends_on = [aws_cloudwatch_log_group.verification]
}

resource "aws_lambda_permission" "allow_sns_invoke_verification" {
  count = var.enable_verification_lambda ? 1 : 0

  statement_id  = "AllowExecutionFromSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.verification[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.verification_sns_topic_arn
}

resource "aws_sns_topic_subscription" "verification_feedback" {
  count = var.enable_verification_lambda ? 1 : 0

  topic_arn = var.verification_sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.verification[0].arn

  depends_on = [aws_lambda_permission.allow_sns_invoke_verification]
}

# Stable aliases for safe Lambda traffic shifting via CodeDeploy
resource "aws_lambda_alias" "log_live" {
  count = var.enable_log_lambda ? 1 : 0

  name             = "live"
  function_name    = aws_lambda_function.log[0].function_name
  function_version = aws_lambda_function.log[0].version
}

resource "aws_lambda_alias" "aml_live" {
  count = var.enable_aml_lambda ? 1 : 0

  name             = "live"
  function_name    = aws_lambda_function.aml[0].function_name
  function_version = aws_lambda_function.aml[0].version
}

resource "aws_lambda_alias" "sftp_transaction_collector_live" {
  count = var.enable_sftp_transaction_collector ? 1 : 0

  name             = "live"
  function_name    = aws_lambda_function.sftp_transaction_collector[0].function_name
  function_version = aws_lambda_function.sftp_transaction_collector[0].version
}

resource "aws_lambda_alias" "verification_live" {
  count = var.enable_verification_lambda ? 1 : 0

  name             = "live"
  function_name    = aws_lambda_function.verification[0].function_name
  function_version = aws_lambda_function.verification[0].version
}
