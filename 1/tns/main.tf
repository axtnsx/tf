terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }

  required_version = "~> 1.2.0"
}


variable region {
  type     = string
  default  = "eu-central-1"
  nullable = false
}


provider "aws" {
  region = var.region


  default_tags {
    tags = {
      Blax = "Blix"
    }
  }
}

## module "vpc-index" {
##   source = "../modules/vpc-index"
## 
##   region = var.region
##   cidr = "10.15.0.0/16"
##   private_subnets = [
##     { cidr="10.15.10.0/24", zone="a" },
##     { cidr="10.15.11.0/24", zone="b" },
##     { cidr="10.15.12.0/24", zone="c" }
##   ]
##   public_subnets = [
##     { cidr="10.15.20.0/24", zone="a" },
##     { cidr="10.15.21.0/24", zone="b" },
##     { cidr="10.15.22.0/24", zone="c" }
##   ]
## }

module "vpc" {
  source = "../modules/vpc"

  region = var.region
  cidr = "10.10.0.0/16"
  private_subnets = [
    { cidr="10.10.10.0/24", zone="a" },
    { cidr="10.10.11.0/24", zone="b" },
    { cidr="10.10.12.0/24", zone="c" }
  ]
  public_subnets = [
    { cidr="10.10.20.0/24", zone="a" },
    { cidr="10.10.21.0/24", zone="b" },
    { cidr="10.10.22.0/24", zone="c" }
  ]
}

## module "vpc-blax" {
##   source = "../modules/vpc"
## 
##   region = var.region
##   cidr = "10.11.0.0/16"
##   private_subnets = [
##     { cidr="10.11.10.0/24", zone="a" },
##     { cidr="10.11.11.0/24", zone="b" },
##     { cidr="10.11.12.0/24", zone="c" }
##   ]
##   public_subnets = [
##     { cidr="10.11.20.0/24", zone="a" },
##     { cidr="10.11.21.0/24", zone="b" },
##     { cidr="10.11.22.0/24", zone="c" }
##   ]
## }

### instance ###

## security group
resource "aws_security_group" "tns-sg-blax" {
  name = "tns-sg-blax"
  vpc_id = module.vpc.vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

## key
resource "aws_key_pair" "tonys-test" {
  key_name   = "tonys-test"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCG9umMNi0vZcJCRttfHoGIHJXIgJeH+bZGurxFr+7IPPGFFSwEn1Exlp1Qpwj2lQ0yb1MC/zZUH8Ep0LhdWtkkpRSpRtrIyOI2FTv+dUuLnq6nP5gEDkW+VznQjMluYGp//nCG5eBbnsvloe4CFM73wlwPpKHx0a+JFox75msy+BI34oDgbl1zoQkL4uS10zXbK1qxzRe4dG/EjPKKLFTGrIz7IU1qUMS8ACBcov8s9eyU2pMPvaAWEMTnSX6XOFEKO3YeZv8jVU3KvJZ5yQskCfxNvwtCOwlUmJwTnyNxSzMcZDiOAu9dyQTsamhCBzD0Q/ndk2A71qGbdDPvfQ09"

  tags = {
    Owner = "Tns Tns"
  }

}

data "cloudinit_config" "natgw" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = file("natgw-user-data")
  }
}

data "cloudinit_config" "blax" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/blax-user-data", {
      blax: aws_security_group.tns-sg-blax.id
    })
  }
}

## route in default route table ##

resource "aws_default_route_table" "ts_vpc" {
  default_route_table_id = module.vpc.vpc.default_route_table_id

  route {
    cidr_block = "10.20.30.0/24"
    instance_id = aws_instance.natgw.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = aws_instance.natgw.id
  }

}

## route in default route table ##

## instance
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Canonical
  owners = [ "099720109477" ]
}

data "aws_ami" "natgw" {
  most_recent = true

  filter {
    name   = "name"
    values = [ "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*" ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Canonical
  owners = [ "099720109477" ]
}

##resource "aws_network_interface" "blax-eth-1" {
##  subnet_id   = random_shuffle.subnet.result[0]
##  security_groups = [ aws_security_group.tns-sg-blax.id ]
##
##  tags = {
##    Name = "primary_network_interface"
##  }
##}

locals {
  public_subnet_ids  = [ for s in module.vpc.public_subnets:  s.id ]
  private_subnet_ids = [ for s in module.vpc.private_subnets: s.id ]
}

resource "random_shuffle" "private_subnet" {
  input        = local.private_subnet_ids
  result_count = 1
}
resource "random_shuffle" "public_subnet" {
  input        = local.public_subnet_ids
  result_count = 1
}

output "some_public_subnets" {
  value = local.public_subnet_ids
}

output "single_private_subnet" {
  value = random_shuffle.private_subnet
}


data "aws_ec2_instance_type_offerings" "blax" {
  filter {
    name   = "instance-type"
    values = ["t4g.nano", "t3.nano"]
  }

  filter {
    name   = "location"
    values = [ "${var.region}" ]
  }

  location_type = "region"
}

output "blax" {
  value = data.aws_ec2_instance_type_offerings.blax
}

##resource "aws_eip" "eip_natgw" {
##  name = "eip-natgw"
##  instance = aws_instance..id
##  vpc = true
##  
##  tags = {
##    Name = "eip-${var.ec2ResourceName}"
##  }
##
##  lifecycle {
##    prevent_destroy = true
##  }
##}

resource "aws_instance" "natgw" {

  ami           = data.aws_ami.natgw.id
  instance_type = "t4g.nano"

  key_name = aws_key_pair.tonys-test.key_name

  subnet_id = random_shuffle.public_subnet.result[0]
  associate_public_ip_address = true
  source_dest_check = false

  user_data = data.cloudinit_config.natgw.rendered
  ##user_data = data.cloudinit_config.blax.rendered


  ## only new group
  ## vpc_security_group_ids = [ aws_security_group.tns-sg-blax.id ]

  ## default vpc group (important) + new group 
  vpc_security_group_ids = [ module.vpc.vpc.default_security_group_id, aws_security_group.tns-sg-blax.id ]

  lifecycle {

    precondition {
      condition     =  contains(data.aws_ec2_instance_type_offerings.blax.instance_types, "t4g.nano")
      error_message = "The selected Instance Type must be available in ${var.region}"
    }

    ignore_changes = [
      ami,
    ]
  }
}




resource "aws_instance" "blax" {

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.nano"

  key_name = aws_key_pair.tonys-test.key_name

  #subnet_id = random_shuffle.public_subnet.result[0]
  #vpc_security_group_ids = [ module.vpc.vpc.default_security_group_id, aws_security_group.tns-sg-blax.id ]

  subnet_id = random_shuffle.private_subnet.result[0]
  associate_public_ip_address = false

##  network_interface {
##    network_interface_id = aws_network_interface.blax-eth-1.id
##    device_index         = 0
##  }

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}


