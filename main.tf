############################################
# KMS KEY (required for encryption)
############################################

resource "aws_kms_key" "s3_kms" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "s3_kms_alias" {
  name          = "alias/s3-secure-key"
  target_key_id = aws_kms_key.s3_kms.key_id
}

############################################
# SOURCE S3 BUCKET
############################################

resource "aws_s3_bucket" "secure_bucket" {
  bucket = "secure-bucket-demo-123456"
}

############################################
# ACCESS LOGGING BUCKET (required for CKV_AWS_18)
############################################

resource "aws_s3_bucket" "log_bucket" {
  bucket = "secure-bucket-logs-123456"
}

resource "aws_s3_bucket_logging" "logging" {
  bucket = aws_s3_bucket.secure_bucket.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "access-logs/"
}

############################################
# KMS ENCRYPTION (CKV_AWS_145 FIX)
############################################

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_kms.arn
    }
  }
}

############################################
# VERSIONING (required for replication)
############################################

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.secure_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

############################################
# LIFECYCLE (kept from previous fix)
############################################

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

############################################
# CROSS-REGION REPLICATION (CKV fix)
############################################

resource "aws_s3_bucket" "replica_bucket" {
  bucket = "secure-bucket-replica-123456"
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica_bucket.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.versioning]
}

############################################
# IAM ROLE FOR REPLICATION
############################################

resource "aws_iam_role" "replication_role" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
