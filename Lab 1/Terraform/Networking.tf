############################################
# Locals (naming convention: satellite-*)
############################################
locals {
  name_prefix    = var.project_name
  ports_http     = 80
  ports_ssh      = 22
  ports_https    = 443
  ports_dns      = 53
  db_port        = 3306
  tcp_protocol   = "tcp"
  udp_protocol   = "udp"
  all_ip_address = "0.0.0.0/0"
  all_ports      = "-1"
  all_protocol   = "All"
  http           = "http"
  https          = "https"
}

############################################
# VPC + Internet Gateway
############################################

# Explanation: satellite needs a hyperlane—this VPC is the Millennium Falcon’s flight corridor.
resource "aws_vpc" "satellite_vpc01" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc01"
  }
}

# Explanation: Even Wookiees need to reach the wider galaxy—IGW is your door to the public internet.
resource "aws_internet_gateway" "satellite_igw01" {
  vpc_id = aws_vpc.satellite_vpc01.id

  tags = {
    Name = "${local.name_prefix}-igw01"
  }
}

############################################
# Subnets (Public + Private)
############################################

# Explanation: Public subnets are like docking bays—ships can land directly from space (internet).
resource "aws_subnet" "satellite_public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.satellite_vpc01.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-subnet0${count.index + 1}"
  }
}

# Explanation: Private subnets are the hidden Rebel base—no direct access from the internet.
resource "aws_subnet" "satellite_private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.satellite_vpc01.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]



  tags = {
    Name = "${local.name_prefix}-private-subnet0${count.index + 1}"
  }
}

############################################
# NAT Gateway + EIP
############################################

# Explanation: satellite wants the private base to call home—EIP gives the NAT a stable “holonet address.”
resource "aws_eip" "satellite_nat_eip01" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip01"
  }
}

# Explanation: NAT is satellite’s smuggler tunnel—private subnets can reach out without being seen.
resource "aws_nat_gateway" "satellite_nat01" {
  allocation_id = aws_eip.satellite_nat_eip01.id
  subnet_id     = aws_subnet.satellite_public_subnets[0].id # NAT in a public subnet

  tags = {
    Name = "${local.name_prefix}-nat01"
  }

  depends_on = [aws_internet_gateway.satellite_igw01]
}

############################################
# Routing (Public + Private Route Tables)
############################################

# Explanation: Public route table = “open lanes” to the galaxy via IGW.
resource "aws_route_table" "satellite_public_rt01" {
  vpc_id = aws_vpc.satellite_vpc01.id

  tags = {
    Name = "${local.name_prefix}-public-rt01"
  }
}

# Explanation: This route is the Kessel Run—0.0.0.0/0 goes out the IGW.
resource "aws_route" "satellite_public_default_route" {
  route_table_id         = aws_route_table.satellite_public_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.satellite_igw01.id
}

# Explanation: Attach public subnets to the “public lanes.”
resource "aws_route_table_association" "satellite_public_rta" {
  count          = length(aws_subnet.satellite_public_subnets)
  subnet_id      = aws_subnet.satellite_public_subnets[count.index].id
  route_table_id = aws_route_table.satellite_public_rt01.id
}

# Explanation: Private route table = “stay hidden, but still ship supplies.”
resource "aws_route_table" "satellite_private_rt01" {
  vpc_id = aws_vpc.satellite_vpc01.id

  tags = {
    Name = "${local.name_prefix}-private-rt01"
  }
}

# Explanation: Private subnets route outbound internet via NAT (satellite-approved stealth).
resource "aws_route" "satellite_private_default_route" {
  route_table_id         = aws_route_table.satellite_private_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.satellite_nat01.id
}

# Explanation: Attach private subnets to the “stealth lanes.”
resource "aws_route_table_association" "satellite_private_rta" {
  count          = length(aws_subnet.satellite_private_subnets)
  subnet_id      = aws_subnet.satellite_private_subnets[count.index].id
  route_table_id = aws_route_table.satellite_private_rt01.id
}


# ############################################
# # Security Group for VPC Interface Endpoints
# ############################################

# # Explanation: Even endpoints need guards—satellite posts a Wookiee at every airlock.
resource "aws_security_group" "satellite_vpce_sg01" {
  name        = "${local.satellite_prefix}-vpce-sg01"
  description = "SG for VPC Interface Endpoints"
  vpc_id      = aws_vpc.satellite_vpc01.id

  # TODO: Students must allow inbound 443 FROM the EC2 SG (or VPC CIDR) to endpoints.
  # NOTE: Interface endpoints ENIs receive traffic on 443.

  tags = {
    Name = "${local.satellite_prefix}-vpce-sg01"
  }
}
resource "aws_security_group_rule" "satellite_vpce_sg_ingress_https_from_ec2" {
  type                     = "ingress"
  from_port                = local.ports_https
  to_port                  = local.ports_https
  protocol                 = local.tcp_protocol
  security_group_id        = aws_security_group.satellite_vpce_sg01.id
  source_security_group_id = aws_security_group.satellite_ec2_sg01.id
}

# ############################################
# # VPC Endpoint - S3 (Gateway)
# ############################################

# # Explanation: S3 is the supply depot—without this, your private world starves (updates, artifacts, logs).
resource "aws_vpc_endpoint" "satellite_vpce_s3_gw01" {
  vpc_id            = aws_vpc.satellite_vpc01.id
  service_name      = "com.amazonaws.${data.aws_region.satellite_region01.name}.s3"
  vpc_endpoint_type = "Gateway"

  # route_table_ids = [
  #   aws_route_table.satellite_private_rt01.id
  # ]

  tags = {
    Name = "${local.satellite_prefix}-vpce-s3-gw01"
  }
}

# ############################################
# # VPC Endpoints - SSM (Interface)
# ############################################

# # Explanation: SSM is your Force choke—remote control without SSH, and nobody sees your keys.
resource "aws_vpc_endpoint" "satellite_vpce_ssm01" {
  vpc_id              = aws_vpc.satellite_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.satellite_region01.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.satellite_private_subnets[*].id
  security_group_ids = [aws_security_group.satellite_vpce_sg01.id]

  tags = {
    Name = "${local.satellite_prefix}-vpce-ssm01"
  }
}

# # Explanation: ec2messages is the Wookiee messenger—SSM sessions won’t work without it.
resource "aws_vpc_endpoint" "satellite_vpce_ec2messages01" {
  vpc_id              = aws_vpc.satellite_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.satellite_region01.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.satellite_private_subnets[*].id
  security_group_ids = [aws_security_group.satellite_vpce_sg01.id]

  tags = {
    Name = "${local.satellite_prefix}-vpce-ec2messages01"
  }
}

# # Explanation: ssmmessages is the holonet channel—Session Manager needs it to talk back.
resource "aws_vpc_endpoint" "satellite_vpce_ssmmessages01" {
  vpc_id              = aws_vpc.satellite_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.satellite_region01.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.satellite_private_subnets[*].id
  security_group_ids = [aws_security_group.satellite_vpce_sg01.id]

  tags = {
    Name = "${local.satellite_prefix}-vpce-ssmmessages01"
  }
}

# ############################################
# # VPC Endpoint - CloudWatch Logs (Interface)
# ############################################

# # Explanation: CloudWatch Logs is the ship’s black box—satellite wants crash data, always.
resource "aws_vpc_endpoint" "satellite_vpce_logs01" {
  vpc_id              = aws_vpc.satellite_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.satellite_region01.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.satellite_private_subnets[*].id
  security_group_ids = [aws_security_group.satellite_vpce_sg01.id]

  tags = {
    Name = "${local.satellite_prefix}-vpce-logs01"
  }
}

# 1CBonus_A ###################################
# # VPC Endpoint - Secrets Manager (Interface)
# ############################################

# # Explanation: Secrets Manager is the locked vault—satellite doesn’t put passwords on sticky notes.
resource "aws_vpc_endpoint" "satellite_vpce_secrets01" {
  vpc_id              = aws_vpc.satellite_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.satellite_region01.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.satellite_private_subnets[*].id
  security_group_ids = [aws_security_group.satellite_vpce_sg01.id]

  tags = {
    Name = "${local.satellite_prefix}-vpce-secrets01"
  }
}

# ############################################
# # Optional: VPC Endpoint - KMS (Interface)
# ############################################

# # Explanation: KMS is the encryption kyber crystal—satellite prefers locked doors AND locked safes.
resource "aws_vpc_endpoint" "satellite_vpce_kms01" {
  vpc_id              = aws_vpc.satellite_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.satellite_region01.name}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.satellite_private_subnets[*].id
  security_group_ids = [aws_security_group.satellite_vpce_sg01.id]

  tags = {
    Name = "${local.satellite_prefix}-vpce-kms01"
  }
}


# 1CBonus_B###################################
# # Application Load Balancer
# ############################################

# # Explanation: The ALB is your public customs checkpoint — it speaks TLS and forwards to private targets.
resource "aws_lb" "satellite_alb01" {
  name               = "${var.project_name}-alb01"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.satellite_alb_sg01.id]
  subnets         = aws_subnet.satellite_public_subnets[*].id

  # Lab1C_Bonus_E
  access_logs {
    bucket  = aws_s3_bucket.satellite_alb_logs_bucket02[0].bucket
    prefix  = var.alb_access_logs_prefix
    enabled = var.enable_alb_access_logs
  }
  tags = {
    Name = "${var.project_name}-alb01"
  }
}

# ############################################
# # Target Group + Attachment
# ############################################

# # Explanation: Target groups are satellite’s “who do I forward to?” list — private EC2 lives here.
resource "aws_lb_target_group" "satellite_tg01" {
  name     = "${var.project_name}-tg01"
  port     = local.ports_http
  protocol = "HTTP"
  vpc_id   = aws_vpc.satellite_vpc01.id

  # TODO: students set health check path to something real (e.g., /health)
  health_check {
    enabled             = true
    interval            = 30 #TODO: adjust intervals to something more realistic
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-tg01"
  }
}

# # Explanation: satellite personally introduces the ALB to the private EC2 — “this is my friend, don’t shoot.”
resource "aws_lb_target_group_attachment" "satellite_tg_attach01" {
  target_group_arn = aws_lb_target_group.satellite_tg01.arn
  target_id        = aws_instance.satellite_ec201_private_bonus_A.id
  port             = local.ports_http
}

# 1C_Bonus_B #################################
# # ALB Listeners: HTTP -> HTTPS redirect, HTTPS -> TG
# ############################################

# Explanation: HTTP listener is the decoy airlock — it redirects everyone to the secure entrance.
resource "aws_lb_listener" "satellite_http_listener01" {
  load_balancer_arn = aws_lb.satellite_alb01.arn
  port              = local.ports_http
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = tostring(local.ports_https)
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# # Explanation: HTTPS listener is the real hangar bay — TLS terminates here, then traffic goes to private targets.
resource "aws_lb_listener" "satellite_https_listener01" {
  load_balancer_arn = aws_lb.satellite_alb01.arn
  port              = local.ports_https
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  //certificate_arn   = aws_acm_certificate.pawserenity_acm_cert01.arn
  certificate_arn = aws_acm_certificate_validation.alb_origin_cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.satellite_tg01.arn
  }
}

# 1C_Bonus_B #################################
# # WAFv2 Web ACL (Basic managed rules)
# ############################################

# # Explanation: WAF is the shield generator — it blocks the cheap blaster fire before it hits your ALB.
resource "aws_wafv2_web_acl" "satellite_waf01" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.project_name}-waf01"
  scope = "REGIONAL" #Cloudfront - scoped ACLs cannot attach to ALB. ALBs required regional ACLs

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf01"
    sampled_requests_enabled   = true
  }

  # Explanation: AWS managed rules are like hiring Rebel commandos — they’ve seen every trick.
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "${var.project_name}-waf01"
  }
}

# # Explanation: Attach the shield generator to the customs checkpoint — ALB is now protected.
resource "aws_wafv2_web_acl_association" "satellite_waf_assoc01" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_lb.satellite_alb01.arn
  web_acl_arn  = aws_wafv2_web_acl.satellite_waf01[0].arn
}