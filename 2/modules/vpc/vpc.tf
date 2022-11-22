
### terraform ###

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }

  required_version = "~> 1.2.0"
}

provider "aws" {
  profile = "admin-sandbox"
  region  = var.region
}

### terraform ###


### variables ###

variable region {
  type     = string
  default  = "us-east-1"
  nullable = false
}

variable "cidr" { 
  type     = string
  default  = "10.12.0.0/16"
  nullable = true
}

variable "private_subnets" {
  type = list(object({
    cidr = string,
    zone = string
  }))

  default = [
    { cidr="10.12.10.0/24", zone="a" },
    { cidr="10.12.11.0/24", zone="b" },
    { cidr="10.12.12.0/24", zone="c" }
  ]

  validation {
    condition     = length(var.private_subnets) < 4 && length(var.private_subnets) > 1
    error_message = "Number of subnets must be two or three."
  }

}

variable "public_subnets" {
  type = list(object({
    cidr = string,
    zone = string
  }))

  default = [
    { cidr="10.12.20.0/24", zone="a" },
    { cidr="10.12.21.0/24", zone="b" },
    { cidr="10.12.22.0/24", zone="c" }
  ]

}

### variables ###


### networks ###

resource "aws_vpc" "ts_vpc" {
  cidr_block = var.cidr

  tags = {
    Name = "auc"
  }
}

### networks ###

### data sources ###

data "aws_region" "current" { }

data "aws_availability_zones" "available" {
  state = "available"
}

### data sources ###


### subnets ###


resource "aws_subnet" "private_subnets" {

  for_each =  { for idx, record in var.private_subnets: record.cidr => record }
  ## index instead of subnet's cidr
  ##for_each =  { for idx, record in var.private_subnets: idx => record }

  vpc_id     = aws_vpc.ts_vpc.id

  availability_zone = "${var.region}${each.value.zone}"
  cidr_block = each.value.cidr

  tags = {
    Name = "Private Subnet ${var.region}${ each.value.zone }"
    Zone = "Zone ${var.region}${ each.value.zone }"
  }

  lifecycle {
    precondition {
      condition     =  contains(data.aws_availability_zones.available.names, "${var.region}${each.value.zone}")
      error_message = "The selected Zone must be available in ${var.region}"
    }
  }

}

resource "aws_subnet" "public_subnets" {

  for_each =  { for idx, record in var.public_subnets: record.cidr => record }
  vpc_id     = aws_vpc.ts_vpc.id

  availability_zone = "${var.region}${each.value.zone}"
  cidr_block = each.value.cidr
  map_public_ip_on_launch = true

  tags = {
    Name = "Private Subnet ${var.region}${ each.value.zone }"
    Zone = "Zone ${var.region}${ each.value.zone }"
  }

  lifecycle {
    precondition {
      condition     =  contains(data.aws_availability_zones.available.names, "${var.region}${each.value.zone}")
      error_message = "The selected Zone must be available in ${var.region}"
    }
  }

}

### subnets ###


### gateways and routing ###

## internet gateway
## allows communications with Internet
resource "aws_internet_gateway" "ts_ig" {
  vpc_id = aws_vpc.ts_vpc.id
}

## main route table
## all routes should go here
resource "aws_route_table" "ts_rt_main" {
  vpc_id = aws_vpc.ts_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ts_ig.id
  }

  tags = {
    Name = "auc"
  }
}

## route table association
## subnets that use main route table
resource "aws_route_table_association" "ts_rt_association" {

  for_each =  { for idx, record in aws_subnet.public_subnets: idx => record }

  subnet_id = each.value.id
  route_table_id = aws_route_table.ts_rt_main.id
}

### gateways and routing ###




### output ###

output "vpc" {
  description = "VPC"
  value       = aws_vpc.ts_vpc
}

output "vpcid" {
  description = "VPC ID"
  value       = aws_vpc.ts_vpc.id
}

output "region" {
  description = "Current REGION"
  value       = data.aws_region.current
}

output "azety" {
  description = "Available AZs"
  value       = data.aws_availability_zones.available
}

output "public_subnets" {
  description = "Public Subnets"
  value       = aws_subnet.public_subnets
}

output "private_subnets" {
  description = "Private Subnets"
  value       = aws_subnet.private_subnets
}

### output ###
