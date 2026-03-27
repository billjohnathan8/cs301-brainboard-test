#--------------------------------------------------------------
# DynamoDB Module
# On-demand DynamoDB tables for audit logs and AML results.
#--------------------------------------------------------------

# --- Audit Logs Table ---

resource "aws_dynamodb_table" "audit_logs" {
  count = var.enable_audit_table ? 1 : 0

  name         = "${var.name_prefix}-audit-logs"
  billing_mode = var.billing_mode
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "client_id"
    type = "S"
  }

  global_secondary_index {
    name            = "user-index"
    projection_type = "ALL"
    hash_key        = "user_id"
    range_key       = "sk"
  }

  global_secondary_index {
    name            = "client-index"
    projection_type = "ALL"
    hash_key        = "client_id"
    range_key       = "sk"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  ttl {
    attribute_name = "ttl"
    enabled        = var.enable_ttl
  }

  tags = {
    Name = "${var.name_prefix}-audit-logs"
  }
}

# --- AML Reports Table ---

resource "aws_dynamodb_table" "aml_reports" {
  count = var.enable_aml_table ? 1 : 0

  name         = "${var.name_prefix}-aml-reports"
  billing_mode = var.billing_mode
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "entity_id"
    type = "S"
  }

  global_secondary_index {
    name            = "entity-index"
    projection_type = "ALL"
    hash_key        = "entity_id"
    range_key       = "sk"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  ttl {
    attribute_name = "ttl"
    enabled        = var.enable_ttl
  }

  tags = {
    Name = "${var.name_prefix}-aml-reports"
  }
}
