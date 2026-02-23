############################################
# EC2 Instance (App Host)
############################################

# Explanation: This is your “Han Solo box”—it talks to RDS and complains loudly when the DB is down.

resource "aws_instance" "satellite_ec2_01" {
  ami                         = var.ec2_ami_id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.satellite_public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.satellite_ec2_sg01.id]
  iam_instance_profile        = aws_iam_instance_profile.satellite_instance_profile01.name
  user_data_replace_on_change = true
  associate_public_ip_address = true

  # TODO: student supplies user_data to install app + CW agent + configure log shipping
  user_data  = file("${path.module}/1a_user_data.sh")
  depends_on = [aws_db_instance.satellite_rds01]

  tags = {
    Name = "${local.name_prefix}-ec2_01-public-lab1A"
  }
}

resource "aws_instance" "satellite_ec2_02" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.satellite_public_subnets[0].id
  vpc_security_group_ids = [aws_security_group.satellite_ec2_sg02.id]
  iam_instance_profile   = aws_iam_instance_profile.satellite_instance_profile01.name
  associate_public_ip_address = true

  tags = {
    Name = "${local.name_prefix}-bastion-host"
  }
}

resource "aws_instance" "satellite_ec_03" {
  ami                         = var.ec2_ami_id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.satellite_private_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.satellite_ec2_sg02.id]
  iam_instance_profile        = aws_iam_instance_profile.satellite_instance_profile01.name
  associate_public_ip_address = false

  tags = {
    Name = "${local.name_prefix}-ec2_03-private"
  }
}

# ############################################
# # Move EC2 into PRIVATE subnet (no public IP)
# ############################################

# # Explanation: satellite hates exposure—private subnets keep your compute off the public holonet.  EC201 is used in Bonus_B
resource "aws_instance" "satellite_ec201_private_bonus_A" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.satellite_private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.satellite_ec2_sg01.id] #This would add a security group on port 80 instead of using only the ALB
  iam_instance_profile   = aws_iam_instance_profile.satellite_instance_profile01.name
  security_groups        = [aws_security_group.satellite_alb_sg01.id]

  # TODO: Students should remove/disable SSH inbound rules entirely and rely on SSM.
  # TODO: Students add user_data that installs app + CW agent; for true hard mode use a baked AMI.
  user_data                   = file("${path.module}/1a_user_data.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "${local.satellite_prefix}-ec201-private-bonus-labs_A"
  }
}