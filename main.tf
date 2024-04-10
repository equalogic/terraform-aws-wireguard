terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Automatically find the latest version of our operating system image (e.g. Ubuntu)
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["${var.ami_prefix}-${var.ami_release}-${var.ami_arch}-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = [var.ami_owner_id]
}

# turn the sg into a sorted list of string
locals {
  sg_wireguard_external = sort([aws_security_group.sg_wireguard_external.id])
}

# clean up and concat the above wireguard default sg with the additional_security_group_ids
locals {
  security_groups_ids = compact(concat(var.additional_security_group_ids, local.sg_wireguard_external))
}

locals {
  launch_name_prefix = "wireguard-${var.env}-"
  wg_client_data = templatefile("${path.module}/templates/client-data.tftpl", {
    users                = var.wg_clients,
    persistent_keepalive = var.wg_persistent_keepalive
  })
}

resource "aws_launch_template" "wireguard_launch_config" {
  name_prefix   = local.launch_name_prefix
  image_id      = var.ami_id == null ? data.aws_ami.ubuntu.id : var.ami_id
  instance_type = var.instance_type
  key_name      = var.ssh_key_id
  iam_instance_profile {
    arn = aws_iam_instance_profile.wireguard_profile.arn
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.tftpl", {
    wg_server_private_key_param = var.wg_server_private_key_param
    wg_server_net               = var.wg_server_net
    wg_server_port              = var.wg_server_port
    peers                       = local.wg_client_data
    use_eip                     = var.use_eip ? "enabled" : "disabled"
    install_ssm                 = var.install_ssm ? "enabled" : "disabled"
    eip_id                      = var.eip_id
    wg_server_interface         = var.wg_server_interface
    arch                        = var.ami_arch
    wg_allowed_cidr_blocks      = join(" ", var.wg_allowed_cidr_blocks)
  }))

  network_interfaces {
    associate_public_ip_address = var.use_eip
    security_groups             = local.security_groups_ids
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      launch-template-name = local.launch_name_prefix
      project              = "wireguard"
      env                  = var.env
      tf-managed           = "True"
    }
  }
}

resource "aws_autoscaling_group" "wireguard_asg" {
  name                 = aws_launch_template.wireguard_launch_config.name
  min_size             = var.asg_min_size
  desired_capacity     = var.asg_desired_capacity
  max_size             = var.asg_max_size
  vpc_zone_identifier  = var.subnet_ids
  health_check_type    = "EC2"
  termination_policies = ["OldestLaunchConfiguration", "OldestInstance"]
  target_group_arns    = var.target_group_arns

  launch_template {
    id      = aws_launch_template.wireguard_launch_config.id
    version = aws_launch_template.wireguard_launch_config.latest_version
  }

  lifecycle {
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
  }

  tag {
    key                 = "Name"
    value               = aws_launch_template.wireguard_launch_config.name
    propagate_at_launch = true
  }

  tag {
    key                 = "env"
    value               = var.env
    propagate_at_launch = true
  }
}

