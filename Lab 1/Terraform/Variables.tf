variable "aws_region" {
  description = "AWS Region for the satellite fleet to patrol."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for naming. Students should change from 'satellite' to their own."
  type        = string
  default     = "satellite"
}

variable "vpc_cidr" {
  description = "VPC CIDR (use 10.x.x.x/xx as instructed)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "azs" {
  description = "Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 app host."
  type        = string
  default     = "ami-068c0051b15cdb816"
}

variable "ec2_instance_type" {
  description = "EC2 instance size for the app."
  type        = string
  default     = "t3.micro"
}

variable "db_engine" {
  description = "RDS engine."
  type        = string
  default     = "mysql"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "elysium"
}

variable "db_username" {
  description = "DB master username (students should use Secrets Manager in 1B/1C)."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "DB master password (DO NOT hardcode in real life; for lab only)."
  type        = string
  sensitive   = true
  default     = "Quasar123!"
}

variable "sns_email_endpoint" {
  description = "Email for SNS subscription (PagerDuty simulation)."
  type        = string
  default     = "kevinwillocks@gmail.com"
}

variable "my_ip_cidr" {
  description = "Your device's IP in CIDR"
  type        = string
}

variable "storage_type" {
  default = "gp2"
  type    = string
}

variable "hosted_zone_id" {
  type    = string
  default = "Z0756527XY5EXU462HMZ"
}

variable "all_ip_address" {
  type    = string
  default = "0.0.0.0/0"
}

variable "manage_route53_in_terraform" {
  description = "If true, create/manage Route53 hosted zone + records in Terraform."
  type        = bool
  default     = true
}

variable "route53_hosted_zone_id" {
  description = "If manage_route53_in_terraform=false, provide existing Hosted Zone ID for domain."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Base domain students registered (e.g., pawserenity.click)."
  type        = string
  default     = "pawserenity.click"
}

variable "app_subdomain" {
  description = "App hostname prefix (e.g., www.pawserenity.click)."
  type        = string
  default     = "www"
}

variable "certificate_validation_method" {
  description = "ACM validation method. Students can do DNS (Route53) or EMAIL."
  type        = string
  default     = "DNS"
}

variable "enable_waf" {
  description = "Toggle WAF creation."
  type        = bool
  default     = true
}

variable "alb_5xx_threshold" {
  description = "Alarm threshold for ALB 5xx count."
  type        = number
  default     = 10
}

variable "alb_5xx_period_seconds" {
  description = "CloudWatch alarm period."
  type        = number
  default     = 300
}

variable "alb_5xx_evaluation_periods" {
  description = "Evaluation periods for alarm."
  type        = number
  default     = 1
}
variable "enable_alb_access_logs" {
  description = "Enable ALB access logging to S3."
  type        = bool
  default     = true
}

variable "alb_access_logs_prefix" {
  description = "S3 prefix for ALB access logs."
  type        = string
  default     = "alb-access-logs"
}

variable "satellite_s3_bucket_name" {
  description = "S3 Bucket name for ALB logs"
  default     = "satellite-alb-logs-bucket01"
  type        = string
}

variable "waf_log_destination" {
  description = "Choose ONE destination per WebACL: cloudwatch | s3 | firehose"
  type        = string
  default     = "firehose"
}

variable "waf_log_retention_days" {
  description = "Retention for WAF CloudWatch log group."
  type        = number
  default     = 14
}

variable "enable_waf_sampled_requests_only" {
  description = "If true, students can optionally filter/redact fields later. (Placeholder toggle.)"
  type        = bool
  default     = false
}