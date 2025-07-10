terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Automatically find the latest version of our operating system image (e.g. Ubuntu)
data "aws_ami" "os" {
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

resource "aws_launch_configuration" "wireguard_launch_config" {
  name_prefix          = "wireguard-${var.env}-"
  image_id             = var.ami_id != null ? var.ami_id : data.aws_ami.os.id
  instance_type        = var.instance_type
  key_name             = var.ssh_key_id
  iam_instance_profile = (var.use_eip ? aws_iam_instance_profile.wireguard_profile[0].name : null)
  user_data = templatefile("${path.module}/templates/user-data.txt", {
    wg_server_private_key = data.aws_ssm_parameter.wg_server_private_key.value
    wg_server_net         = var.wg_server_net
    wg_server_port        = var.wg_server_port
    peers = join("\n", [
      for client in var.wg_clients : templatefile("${path.module}/templates/client-data.tpl", {
        client_name          = client.name
        client_pub_key       = client.public_key
        client_ip            = client.client_ip
        persistent_keepalive = var.wg_persistent_keepalive
      })
    ])
    use_eip             = var.use_eip ? "enabled" : "disabled"
    eip_id              = var.eip_id
    wg_server_interface = var.wg_server_interface
  })
  security_groups             = local.security_groups_ids
  associate_public_ip_address = var.use_eip

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "wireguard_asg" {
  name                 = aws_launch_configuration.wireguard_launch_config.name
  launch_configuration = aws_launch_configuration.wireguard_launch_config.name
  min_size             = var.asg_min_size
  desired_capacity     = var.asg_desired_capacity
  max_size             = var.asg_max_size
  vpc_zone_identifier  = var.subnet_ids
  health_check_type    = "EC2"
  termination_policies = ["OldestLaunchConfiguration", "OldestInstance"]
  target_group_arns    = var.target_group_arns

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = aws_launch_configuration.wireguard_launch_config.name
    propagate_at_launch = true
  }

  tag {
    key                 = "env"
    value               = var.env
    propagate_at_launch = true
  }
}
