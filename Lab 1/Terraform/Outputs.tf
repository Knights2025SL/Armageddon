# Explanation: Outputs are your mission report—what got built and where to find it.
output "satellite_vpc_id" {
  value = aws_vpc.satellite_vpc01.id
}

output "satellite_public_subnet_ids" {
  value = aws_subnet.satellite_public_subnets[*].id
}

output "satellite_private_subnet_ids" {
  value = aws_subnet.satellite_private_subnets[*].id
}

# output "satellite_ec2_instance_id" {
#   value = aws_instance.satellite_ec201.id
# }

output "satellite_rds_endpoint" {
  value = aws_db_instance.satellite_rds01.address
}

output "satellite_sns_topic_arn" {
  value = aws_sns_topic.satellite_sns_topic01.arn
}

output "satellite_log_group_name" {
  value = aws_cloudwatch_log_group.satellite_log_group01.name
}

output "satellite_route53_zone_id" {
  value = var.hosted_zone_id
}

output "satellite_app_url_https" {
  value = "https://${var.app_subdomain}.${var.domain_name}"
}

output "satellite_pawserenity_cert_arn" {
  value     = aws_acm_certificate.pawserenity_acm_cert01
  sensitive = true
}

output "satellite_pawserenity_cert_arn_region" {
  value     = aws_acm_certificate.pawserenity_acm_cert01.region
  sensitive = false
}

output "pawserenity_apex_alias_record" {
  value = aws_route53_record.pawserenity_apex_alias.records
}

output "pawserenity_www_alias_record" {
  value = aws_route53_record.pawserenity_www_alias.records
}

output "pawserenity_apex_alias" {
  value = aws_route53_record.pawserenity_apex_alias.alias
}

output "pawserenity_www_alia_ttl" {
  value = aws_route53_record.pawserenity_www_alias.ttl
}

#Bonus-A outputs (append to outputs.tf)

# Explanation: These outputs prove Chewbacca built private hyperspace lanes (endpoints) instead of public chaos.
output "satellite_vpce_ssm_id" {
  value = aws_vpc_endpoint.satellite_vpce_ssm01.id
}

output "satellite_vpce_logs_id" {
  value = aws_vpc_endpoint.satellite_vpce_logs01.id
}

output "satellite_vpce_secrets_id" {
  value = aws_vpc_endpoint.satellite_vpce_secrets01.id
}

output "satellite_vpce_s3_id" {
  value = aws_vpc_endpoint.satellite_vpce_s3_gw01.id
}

output "satellite_private_ec2_instance_id_bonus" {
  value = aws_instance.satellite_ec201_private_bonus_A.id
}

# # Explanation: Outputs are the mission coordinates — where to point your browser and your blasters.
output "satellite_alb_dns_name" {
  value = aws_lb.satellite_alb01.dns_name
}

output "satellite_app_fqdn" {
  value = "${var.app_subdomain}.${var.domain_name}"
}

output "satellite_target_group_arn" {
  value = aws_lb_target_group.satellite_tg01.arn
}

output "satellite_acm_cert_arn" {
  value = aws_acm_certificate.pawserenity_acm_cert01.arn
}

output "satellite_waf_arn" {
  value = var.enable_waf ? aws_wafv2_web_acl.satellite_waf01[0].arn : null
}

output "satellite_dashboard_name" {
  value = aws_cloudwatch_dashboard.satellite_dashboard01.dashboard_name
}

# Explanation: The apex URL is the front gate—humans type this when they forget subdomains.
output "pawserenity_apex_url_https" {
  value = "https://${var.domain_name}"
}

# Explanation: Log bucket name is where the footprints live—useful when hunting 5xx or WAF blocks.
output "satellite_alb_logs_bucket_name" {
  value = var.enable_alb_access_logs ? aws_s3_bucket.satellite_alb_logs_bucket01.bucket : null
}

output "satellite_s3_ownership_control" {
  value = aws_s3_bucket_ownership_controls.satellite_alb_logs_bucket01_ownership.rule
}

output "satellite_s3_acl" {
  value = aws_s3_bucket_acl.satellite_alb_logs_bucket01_acl.acl
}

output "satellite_origin_header_value" {
  value     = random_password.satellite_origin_header_value01.result
  sensitive = true
}