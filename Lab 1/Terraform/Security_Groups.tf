############################################
# Security Groups (EC2 + RDS)
############################################

# Explanation: EC2 SG is satellite’s bodyguard—only let in what you mean to.
resource "aws_security_group" "satellite_ec2_sg01" {
  name        = "${local.name_prefix}-ec2-sg01"
  description = "EC2 app security group"
  vpc_id      = aws_vpc.satellite_vpc01.id

  tags = {
    Name = "${local.name_prefix}-ec2-sg01"
  }
}
resource "aws_security_group" "satellite_ec2_sg02" {
  name        = "${local.name_prefix}-ec2-sg02"
  description = "EC2 app security group"
  vpc_id      = aws_vpc.satellite_vpc01.id

  tags = {
    Name = "${local.name_prefix}-ec2-sg02"
  }
}

resource "aws_vpc_security_group_ingress_rule" "satellite_ec2_sg_ingress_http" {
  ip_protocol       = local.tcp_protocol
  security_group_id = aws_security_group.satellite_ec2_sg01.id
  from_port         = local.ports_http
  to_port           = local.ports_http
  cidr_ipv4         = local.all_ip_address
}
resource "aws_vpc_security_group_egress_rule" "satellite_ec2_sg_egress_db" {
  ip_protocol       = local.all_protocol
  security_group_id = aws_security_group.satellite_ec2_sg01.id
  from_port         = local.all_ports
  to_port           = local.all_ports
  cidr_ipv4         = local.all_ip_address
}


# Explanation: RDS SG is the Rebel vault—only the app server gets a keycard.
resource "aws_security_group" "satellite_rds_sg01" {
  name        = "${local.name_prefix}-rds-sg01"
  description = "RDS security group"
  vpc_id      = aws_vpc.satellite_vpc01.id

  tags = {
    Name = "${local.name_prefix}-rds-sg01"
  }
}
resource "aws_vpc_security_group_ingress_rule" "satellite_rds_sg_ingress_mysql" {
  ip_protocol                  = local.tcp_protocol
  security_group_id            = aws_security_group.satellite_rds_sg01.id
  from_port                    = local.db_port
  to_port                      = local.db_port
  referenced_security_group_id = aws_security_group.satellite_ec2_sg01.id #allow traffic ONLY from specified SG
}

############################################
# RDS Subnet Group
############################################

# Explanation: RDS hides in private subnets like the Rebel base on Hoth—cold, quiet, and not public.
resource "aws_db_subnet_group" "satellite_rds_subnet_group01" {
  name       = "${local.name_prefix}-rds-subnet-group01"
  subnet_ids = aws_subnet.satellite_private_subnets[*].id

  tags = {
    Name = "${local.name_prefix}-rds-subnet-group01"
  }
}

# ############################################
# # Bonus B - ALB (Public) -> Target Group (Private EC2) + TLS + WAF + Monitoring
# ############################################

locals {
  # Explanation: This is the roar address — where the galaxy finds your app.
  satellite_fqdn = "${trim(var.app_subdomain, ".")}.${var.domain_name}"
}

# ############################################
# # Security Group: ALB
# ############################################

# # Explanation: The ALB SG is the blast shield — only allow what the Rebellion needs (80/443).
resource "aws_security_group" "satellite_alb_sg01" {
  name        = "${var.project_name}-alb-sg01"
  description = "ALB security group"
  vpc_id      = aws_vpc.satellite_vpc01.id

  tags = {
    Name = "${var.project_name}-alb-sg01"
  }
}

# TODO: students set outbound to target group port (usually 80) to private targets
# Kevin: Need to investigate this further
resource "aws_vpc_security_group_egress_rule" "satellite_alb_egress_http" {
  ip_protocol                  = local.tcp_protocol
  security_group_id            = aws_security_group.satellite_alb_sg01.id
  referenced_security_group_id = aws_security_group.satellite_ec2_sg01.id #where traffic is going to
  from_port                    = local.ports_http
  to_port                      = aws_lb_target_group.satellite_tg01.port
}
