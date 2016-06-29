# Rancher AWS Infrastructure
# Variable Configuration File

variable "access_key" {
  description = "AWS Access Key ID"
}

variable "secret_key" {
  description = "AWS Secret Access Key"
}

variable "aws_region" {
  description = "AWS Region (ex: eu-central-1, eu-west-1, us-east-1, etc.)"
#  default = "us-east-1"
}

variable "instance_size" {
  description = "Instance size for Rancher Infrastructure"
#  default = "t2.large"
  default = "t2.micro"
}

variable "public_key_path" {
  description = "Path to Public Key"
  default = "./keys/aws-keypair-01.pub"
}

variable "private_key_path" {
  description = "Path to Private Key"
  default = "./keys/aws-keypair-01.pem"
}

variable "key_name" {
  description = "Name of new AWS key pair"
  default = "aws-keypair-01"
}

variable "tag_name" {
    default     = "rancher"
    description = "Name tag prefix"
}

# RancherOS v0.4.5 - HVM
variable "aws_amis" {
  default = {
    eu-central-1 = "ami-8740ade8"
    eu-west-1 = "ami-6343d610"
    sa-east-1 = "ami-0b991167"
    us-east-1 = "ami-812ec0ec"
    us-west-1 = "ami-cc255dac"
    us-west-2 = "ami-58fe0238"
  }
}
