resource "aws_s3_bucket" "satellite_alb_logs_bucket01" {
  bucket        = var.satellite_s3_bucket_name
  force_destroy = true
  tags = {
    "Name" = "alb_logs"
  }
}

resource "aws_s3_bucket_ownership_controls" "satellite_alb_logs_bucket01_ownership" {
  bucket = aws_s3_bucket.satellite_alb_logs_bucket01.id

  rule {
    object_ownership = "BucketOwnerPreferred" #will have to try Bucket owner enforced
  }
}

#access control for s3 bucket
resource "aws_s3_bucket_acl" "satellite_alb_logs_bucket01_acl" {
  bucket = aws_s3_bucket.satellite_alb_logs_bucket01.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.satellite_alb_logs_bucket01_ownership]
}

resource "aws_s3_bucket_policy" "satellite_alb_logs_bucket01_access" {
  bucket = aws_s3_bucket.satellite_alb_logs_bucket01.id
  policy = data.aws_iam_policy_document.satellite_s3_access_from_alb.json
}


data "aws_caller_identity" "current" {}

#bucket policy details
data "aws_iam_policy_document" "satellite_s3_access_from_alb" {
  statement {
    sid    = "AllowALBLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    # ALB writes to: <prefix>/AWSLogs/<account-id>/...
    resources = [
      "${aws_s3_bucket.satellite_alb_logs_bucket01.arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

#lab1C_Bonus_E##############################
# S3 bucket for ALB access logs
############################################

# Explanation: This bucket is satellite’s log vault—every visitor to the ALB leaves footprints here.
resource "aws_s3_bucket" "satellite_alb_logs_bucket02" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = "${var.project_name}-alb-logs-${data.aws_caller_identity.satellite_self01.account_id}"

  tags = {
    Name = "${var.project_name}-alb-logs-bucket02"
  }
}

# Explanation: Block public access—satellite does not publish the ship’s black box to the galaxy.
resource "aws_s3_bucket_public_access_block" "satellite_alb_logs_pab01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.satellite_alb_logs_bucket02[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: Bucket ownership controls prevent log delivery chaos—satellite likes clean chain-of-custody.
resource "aws_s3_bucket_ownership_controls" "satellite_alb_logs_owner01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.satellite_alb_logs_bucket02[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Explanation: TLS-only—satellite growls at plaintext and throws it out an airlock.
resource "aws_s3_bucket_policy" "satellite_alb_logs_policy01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.satellite_alb_logs_bucket02[0].id

  # NOTE: This is a skeleton. Students may need to adjust for region/account specifics.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.satellite_alb_logs_bucket02[0].arn,
          "${aws_s3_bucket.satellite_alb_logs_bucket02[0].arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.satellite_alb_logs_bucket02[0].arn
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.satellite_alb_logs_bucket02[0].arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AllowELBPutObject"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.satellite_alb_logs_bucket02[0].arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}