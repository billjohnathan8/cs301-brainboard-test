#--------------------------------------------------------------
# S3 Module
# S3 buckets for frontend static hosting, transaction mocked SFTP ingestion,
# and their associated policies and CORS rules.
#--------------------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket        = var.frontend_bucket_name
  force_destroy = var.frontend_bucket_force_destroy
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = !var.frontend_bucket_allow_public
  block_public_policy     = !var.frontend_bucket_allow_public
  ignore_public_acls      = !var.frontend_bucket_allow_public
  restrict_public_buckets = !var.frontend_bucket_allow_public
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# --- S3 static website hosting (when CloudFront is disabled) ---

resource "aws_s3_bucket_website_configuration" "frontend" {
  count  = var.frontend_bucket_allow_public ? 1 : 0
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "frontend_public_read" {
  count  = var.frontend_bucket_allow_public ? 1 : 0
  bucket = aws_s3_bucket.frontend.id

  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}

# --- Verification documents bucket (optional) ---

resource "aws_s3_bucket" "verification" {
  count = var.enable_verification_bucket ? 1 : 0

  bucket        = var.verification_bucket_name
  force_destroy = false

  tags = {
    Name = var.verification_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "verification" {
  count = var.enable_verification_bucket ? 1 : 0

  bucket = aws_s3_bucket.verification[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "verification" {
  count = var.enable_verification_bucket ? 1 : 0

  bucket = aws_s3_bucket.verification[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "verification" {
  count = var.enable_verification_bucket ? 1 : 0

  bucket = aws_s3_bucket.verification[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Transaction ingestion source bucket (optional, legacy 'sftp' naming) ---

resource "aws_s3_bucket" "transaction_sftp" {
  count = var.enable_transaction_sftp_bucket ? 1 : 0

  bucket        = var.transaction_sftp_bucket_name
  force_destroy = false

  tags = {
    Name = var.transaction_sftp_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "transaction_sftp" {
  count = var.enable_transaction_sftp_bucket ? 1 : 0

  bucket = aws_s3_bucket.transaction_sftp[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "transaction_sftp" {
  count = var.enable_transaction_sftp_bucket ? 1 : 0

  bucket = aws_s3_bucket.transaction_sftp[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "transaction_sftp" {
  count = var.enable_transaction_sftp_bucket ? 1 : 0

  bucket = aws_s3_bucket.transaction_sftp[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
