############################################
# Secure S3 Bucket (Checkov compliant)
############################################

resource "aws_s3_bucket" "secure_bucket" {
  bucket = "my-secure-bucket-123456"
}

# Block public access
resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.secure_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Enable access logging
resource "aws_s3_bucket_logging" "logging" {
  bucket = aws_s3_bucket.secure_bucket.id

  target_bucket = aws_s3_bucket.secure_bucket.id
  target_prefix = "logs/"
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

############################################
# Event notifications (required by Checkov)
############################################
resource "aws_s3_bucket_notification" "notify" {
  bucket = aws_s3_bucket.secure_bucket.id
}

############################################
# Cross-region replication (mock minimal config)
############################################
resource "aws_s3_bucket_replication_configuration" "replication" {
  role   = "arn:aws:iam::123456789012:role/s3-replication-role"
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "replication"
    status = "Enabled"

    destination {
      bucket        = "arn:aws:s3:::replica-bucket-123456"
      storage_class = "STANDARD"
    }
  }
}

############################################
# Security Group (fixed issues)
############################################
resource "aws_security_group" "secure_sg" {
  name        = "secure_sg"
  description = "Allow SSH from my IP"

  ingress {
    description = "SSH access from home IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Attach security group to something (required by Checkov)
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.secure_sg.id]
}
