############################################
# RDS Instance (MySQL)
############################################

# Explanation: This is the holocron of state—your relational data lives here, not on the EC2.
resource "aws_db_instance" "satellite_rds01" {
  identifier               = "${local.name_prefix}-rds01"
  engine                   = var.db_engine
  instance_class           = var.db_instance_class
  storage_type             = var.storage_type
  allocated_storage        = 20
  backup_retention_period  = 7
  db_name                  = var.db_name
  username                 = var.db_username
  password                 = var.db_password
  multi_az                 = true
  delete_automated_backups = false

  db_subnet_group_name   = aws_db_subnet_group.satellite_rds_subnet_group01.name
  vpc_security_group_ids = [aws_security_group.satellite_rds_sg01.id]

  publicly_accessible = false
  skip_final_snapshot = true

  # TODO: student sets multi_az / backups / monitoring as stretch goals

  tags = {
    Name = "${local.name_prefix}-rds01"
  }
}