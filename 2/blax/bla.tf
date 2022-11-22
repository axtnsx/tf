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
  profile = "admin-sandbox"
  region = var.region

#  assume_role {
#    role_arn     = "arn:aws:iam::112233445566:role/tns-role-1-blax"
#    session_name = "blax"
#  }

  default_tags {
    tags = {
      Blax = "Blix"
    }
  }
}

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

module "cpv" {
  source = "../modules/vpc"

  region = var.region
  cidr = "10.17.0.0/16"
  private_subnets = [
    { cidr="10.17.10.0/24", zone="a" },
    { cidr="10.17.11.0/24", zone="b" },
    { cidr="10.17.12.0/24", zone="c" }
  ]
  public_subnets = [
    { cidr="10.17.20.0/24", zone="a" },
    { cidr="10.17.21.0/24", zone="b" },
    { cidr="10.17.22.0/24", zone="c" }
  ]
}
