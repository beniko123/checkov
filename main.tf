############################################
# S3 BUCKET
############################################

resource "aws_s3_bucket" "secure_bucket" {
  bucket = "secure-bucket-demo-123456"

  tags = {
    Name = "secure-bucket"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.secure_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    expiration {
      days = 90
    }

    # FIX for CKV_AWS_300
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

############################################
# SECURITY GROUP
############################################

resource "aws_security_group" "secure_sg" {
  name        = "secure_sg"
  description = "Allow SSH from restricted IP"

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["54.210.231.33/32"]
  }

  # FIX for CKV_AWS_382 (no full open outbound)
  egress {
    description = "Allow HTTPS outbound only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# IAM ROLE FOR EC2 (CKV2_AWS_41 FIX)
############################################

resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}

############################################
# EC2 INSTANCE (ALL CKV FIXES APPLIED)
############################################

resource "aws_instance" "example" {
  ami           = "ami-098e39bafa7e7303d"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.secure_sg.id]

  # CKV_AWS_126 - Enable detailed monitoring
  monitoring = true

  # CKV_AWS_79 - Enforce IMDSv2
  metadata_options {
    http_tokens = "required"
  }

  # CKV_AWS_8 - Encrypt root volume
  root_block_device {
    encrypted = true
  }

  # CKV2_AWS_41 - Attach IAM role
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "secure-ec2"
  }
}
