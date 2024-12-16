provider "aws" {
  region = var.aws_region
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Query VPC by name
data "aws_vpc" "selected" {
  tags = {
    Name = "umbrella-corp"
  }
}

# Query first private subnet in the VPC
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

# Bastion Security Group
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = data.aws_vpc.selected.id  # Updated to use data source

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion-sg"
    Environment = var.environment
  }
}

# Launch Template for Bastion
resource "aws_launch_template" "bastion" {
  name_prefix   = "${var.project_name}-${var.environment}-bastion-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.xlarge"

  network_interfaces {
    security_groups = [aws_security_group.bastion.id]
    subnet_id       = tolist(data.aws_subnets.private.ids)[0]
  }

  key_name = var.ssh_key_name

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-bastion"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "bastion" {
  name                = "${var.project_name}-${var.environment}-bastion-asg"
  desired_capacity    = 1
  max_size           = 1
  min_size           = 0
  target_group_arns  = []
  vpc_zone_identifier = [tolist(data.aws_subnets.private.ids)[0]]

  launch_template {
    id      = aws_launch_template.bastion.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value              = "${var.project_name}-${var.environment}-bastion"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value              = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "AutoScaling"
    value              = "true"
    propagate_at_launch = true
  }
}

# Schedule to start instances (08:30 Bangkok time = 01:30 UTC)
resource "aws_autoscaling_schedule" "start_bastion" {
  scheduled_action_name  = "start_bastion"
  min_size              = 1
  max_size              = 1
  desired_capacity      = 1
  recurrence            = "30 1 * * MON-FRI"
  time_zone             = "Asia/Bangkok"
  autoscaling_group_name = aws_autoscaling_group.bastion.name
}

# Schedule to stop instances (20:00 Bangkok time = 13:00 UTC)
resource "aws_autoscaling_schedule" "stop_bastion" {
  scheduled_action_name  = "stop_bastion"
  min_size              = 0
  max_size              = 0
  desired_capacity      = 0
  recurrence            = "00 20 * * MON-FRI"
  time_zone             = "Asia/Bangkok"
  autoscaling_group_name = aws_autoscaling_group.bastion.name
} 