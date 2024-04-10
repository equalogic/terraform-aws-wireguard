variable "ssh_key_id" {
  description = "A SSH public key ID to add to the VPN instance."
  default     = null
  type        = string
}

variable "instance_type" {
  default     = "t4g.micro"
  description = "The machine type to launch, some machines may offer higher throughput for higher use cases."
  type        = string
}

variable "asg_min_size" {
  default     = 1
  description = "We may want more than one machine in a scaling group, but 1 is recommended."
  type        = number
}

variable "asg_desired_capacity" {
  default     = 1
  description = "We may want more than one machine in a scaling group, but 1 is recommended."
  type        = number
}

variable "asg_max_size" {
  default     = 1
  description = "We may want more than one machine in a scaling group, but 1 is recommended."
  type        = number
}

variable "vpc_id" {
  description = "The VPC ID in which Terraform will launch the resources."
  type        = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnets for the Autoscaling Group to use for launching instances. May be a single subnet, but it must be an element in a list."
}

variable "wg_clients" {
  type        = list(object({ name = string, public_key = string, client_ip = string }))
  description = "List of client objects with IP and public key. See Usage in README for details."
}

variable "wg_server_net" {
  default     = "192.168.2.1/24"
  description = "IP range for vpn server - make sure your Client ips are in this range but not the specific ip i.e. not .1"
  type        = string
}

variable "wg_server_port" {
  default     = 51820
  description = "Port for the vpn server."
  type        = number
}

variable "wg_persistent_keepalive" {
  default     = 25
  description = "Persistent Keepalive - useful for helping connection stability over NATs."
  type        = number
}

variable "use_eip" {
  type        = bool
  default     = false
  description = "Whether to enable Elastic IP switching code in user-data on wg server startup. If true, eip_id must also be set to the ID of the Elastic IP."
}

variable "eip_id" {
  type        = string
  description = "ID of the Elastic IP to use, when use_eip is enabled."
}

variable "additional_security_group_ids" {
  type        = list(string)
  default     = [""]
  description = "Additional security groups if provided, default empty."
}

variable "wg_allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Defines IP ranges WireGuard clients can access, limiting full internet access if desired."
}

variable "target_group_arns" {
  type        = list(string)
  default     = null
  description = "Running a scaling group behind an LB requires this variable, default null means it won't be included if not set."
}

variable "env" {
  default     = "prod"
  description = "The name of environment for WireGuard. Used to differentiate multiple deployments."
  type        = string
}

variable "wg_server_private_key_param" {
  default     = "/wireguard/wg-server-private-key"
  description = "The SSM parameter containing the WG server private key."
  type        = string
}

variable "ami_id" {
  default     = null # we check for this and use a data provider since we can't use it here
  description = "The AWS AMI to use for the WG server, defaults to an Ubuntu AMI if not specified."
  type        = string
}

variable "ami_prefix" {
  default     = "ubuntu/images/hvm-ssd/ubuntu"
  description = "Prefix to look for in AMI name when automatically choosing an image."
  type        = string
}

variable "ami_release" {
  default     = "jammy-22.04"
  description = "OS release to look for in AMI name when automatically choosing an image."
  type        = string
}

variable "ami_arch" {
  default     = "arm64"
  description = "Architecture to look for in AMI name when automatically choosing an image. Ensure this is appropriate for your chosen instance_type."
  type        = string
}

variable "ami_owner_id" {
  default     = "099720109477"
  description = "Look for an AMI with this owner account ID when automatically choosing an image."
  type        = string
}

variable "wg_server_interface" {
  description = "The default interface to forward network traffic to."
  type        = string
  default     = ""
}

variable "install_ssm" {
  description = "Whether to install the Amazon SSM Agent on the EC2 instances"
  type        = bool
  default     = true
}

