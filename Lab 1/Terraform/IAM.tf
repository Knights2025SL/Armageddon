############################################
# IAM Role + Instance Profile for EC2
############################################

# Explanation: satellite refuses to carry static keys—this role lets EC2 assume permissions safely.
resource "aws_iam_role" "satellite_ec2_role01" {
  name = "${local.name_prefix}-ec2-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Explanation: These policies are your Wookiee toolbelt—tighten them (least privilege) as a stretch goal.
resource "aws_iam_role_policy_attachment" "satellite_ec2_ssm_attach" {
  role       = aws_iam_role.satellite_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Explanation: EC2 must read secrets/params during recovery—give it access (students should scope it down).
resource "aws_iam_role_policy_attachment" "satellite_ec2_secrets_attach" {
  role       = aws_iam_role.satellite_ec2_role01.name
  policy_arn = aws_iam_policy.satellite_secrets_policy.arn
}

# Explanation: CloudWatch logs are the “ship’s black box”—you need them when things explode.
resource "aws_iam_role_policy_attachment" "satellite_ec2_cw_attach" {
  role       = aws_iam_role.satellite_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Explanation: Instance profile is the harness that straps the role onto the EC2 like bandolier ammo.
resource "aws_iam_instance_profile" "satellite_instance_profile01" {
  name = "${local.name_prefix}-instance-profile01"
  role = aws_iam_role.satellite_ec2_role01.name
}

resource "aws_iam_policy" "satellite_secrets_policy" {
  name        = "secrets_policy"
  description = "EC2 to RDS using Secrets Manager"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ReadSpecificSecret",
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "arn:aws:secretsmanager:us-east-1:461593447802:secret:lab1a/rds/mysql*"
      }
    ]
  })
}

# 1CBonus_A ##################################
# # Least-Privilege IAM (BONUS A)
# ############################################

# # Explanation: satellite doesn’t hand out the Falcon keys—this policy scopes reads to your lab paths only.
resource "aws_iam_policy" "satellite_leastpriv_read_params01" {
  name        = "${local.satellite_prefix}-lp-ssm-read01"
  description = "Least-privilege read for SSM Parameter Store under /lab/db/*"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadLabDbParams"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.satellite_region01.name}:${data.aws_caller_identity.satellite_self01.account_id}:parameter/lab/db/*"
        ]
      }
    ]
  })
}

# # Explanation: satellite only opens *this* vault—GetSecretValue for only your secret (not the whole planet).
resource "aws_iam_policy" "satellite_leastpriv_read_secret01" {
  name        = "${local.satellite_prefix}-lp-secrets-read01"
  description = "Least-privilege read for the lab DB secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyLabSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.satellite_secret_arn_guess
      }
    ]
  })
}

# # Explanation: When the Falcon logs scream, this lets satellite ship logs to CloudWatch without giving away the Death Star plans.
resource "aws_iam_policy" "satellite_leastpriv_cwlogs01" {
  name        = "${local.satellite_prefix}-lp-cwlogs01"
  description = "Least-privilege CloudWatch Logs write for the app log group"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.satellite_log_group01.arn}:*"
        ]
      }
    ]
  })
}

# # Explanation: Attach the scoped policies—satellite loves power, but only the safe kind.
resource "aws_iam_role_policy_attachment" "satellite_attach_lp_params01" {
  role       = aws_iam_role.satellite_ec2_role01.name
  policy_arn = aws_iam_policy.satellite_leastpriv_read_params01.arn
}

resource "aws_iam_role_policy_attachment" "satellite_attach_lp_secret01" {
  role       = aws_iam_role.satellite_ec2_role01.name
  policy_arn = aws_iam_policy.satellite_leastpriv_read_secret01.arn
}

resource "aws_iam_role_policy_attachment" "satellite_attach_lp_cwlogs01" {
  role       = aws_iam_role.satellite_ec2_role01.name
  policy_arn = aws_iam_policy.satellite_leastpriv_cwlogs01.arn
}