############################################
# Parameter Store (SSM Parameters)
############################################

# Explanation: Parameter Store is satellite’s map—endpoints and config live here for fast recovery.
resource "aws_ssm_parameter" "satellite_db_endpoint" {
  name  = "/lab/db/endpoint"
  type  = "String"
  value = aws_db_instance.satellite_rds01.address

  tags = {
    Name = "${local.name_prefix}-param-db-endpoint"
  }
}

# Explanation: Ports are boring, but even Wookiees need to know which door number to kick in.
resource "aws_ssm_parameter" "satellite_db_port" {
  name  = "/lab/db/port"
  type  = "String"
  value = tostring(aws_db_instance.satellite_rds01.port)

  tags = {
    Name = "${local.name_prefix}-param-db-port"
  }
}

# Explanation: DB name is the label on the crate—without it, you’re rummaging in the dark.
resource "aws_ssm_parameter" "satellite_db_name" {
  name  = "/lab/db/name"
  type  = "String"
  value = var.db_name

  tags = {
    Name = "${local.name_prefix}-param-db-name"
  }
}

############################################
# Secrets Manager (DB Credentials)
############################################

# Explanation: Secrets Manager is satellite’s locked holster—credentials go here, not in code.
#Recovery_window_in_days forces deletion of secrets and allows re-deployment of secret without constantly changing name

resource "aws_secretsmanager_secret" "satellite_db_secret01" {
  name                    = "lab1a/rds/mysql"
  recovery_window_in_days = 0
}

# Explanation: Secret payload—students should align this structure with their app (and support rotation later).
resource "aws_secretsmanager_secret_version" "satellite_db_secret_version01" {
  secret_id = aws_secretsmanager_secret.satellite_db_secret01.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.satellite_rds01.address
    port     = aws_db_instance.satellite_rds01.port
    dbname   = var.db_name
  })
}
