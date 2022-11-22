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

resource "aws_key_pair" "tonys-test" {
  key_name   = "tonys-test"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCG9umMNi0vZcJCRttfHoGIHJXIgJeH+bZGurxFr+7IPPGFFSwEn1Exlp1Qpwj2lQ0yb1MC/zZUH8Ep0LhdWtkkpRSpRtrIyOI2FTv+dUuLnq6nP5gEDkW+VznQjMluYGp//nCG5eBbnsvloe4CFM73wlwPpKHx0a+JFox75msy+BI34oDgbl1zoQkL4uS10zXbK1qxzRe4dG/EjPKKLFTGrIz7IU1qUMS8ACBcov8s9eyU2pMPvaAWEMTnSX6XOFEKO3YeZv8jVU3KvJZ5yQskCfxNvwtCOwlUmJwTnyNxSzMcZDiOAu9dyQTsamhCBzD0Q/ndk2A71qGbdDPvfQ09"

  tags = {
    Owner = "Tns Tns"
  }

}

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


resource "aws_iam_instance_profile" "blax-profile" {
  name = "blax-profile-tonys"
  role = aws_iam_role.blax-role.name
}

resource "aws_iam_role" "blax-role" {
  name = "blax-role-tonys"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
    ]
}
EOF
}

resource "aws_iam_role_policy" "blax-policy" {
  name = "blax-policy-tonys"
  role = "${aws_iam_role.blax-role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_instance" "blax" {

  ami           = data.aws_ami.ubuntu.id

  instance_type = "t3.nano"
  key_name = aws_key_pair.tonys-test.key_name

  user_data = data.cloudinit_config.blax.rendered
  iam_instance_profile = "${aws_iam_instance_profile.blax-profile.name}"

  subnet_id = module.vpc.public_subnets["10.10.20.0/24"].id
  associate_public_ip_address = true

  ## default vpc group (important) + new group
  vpc_security_group_ids = [ module.vpc.vpc.default_security_group_id, aws_security_group.tns-sg-blax.id ]

  lifecycle {

    precondition {
      condition     =  contains(data.aws_ec2_instance_type_offerings.blax.instance_types, "t3.nano")
      error_message = "The selected Instance Type must be available in ${var.region}"
    }

    ignore_changes = [
      ami,
    ]
  }

}

## commands:
## ssh -i keys/tonys.pem -l ubuntu $(terraform state show aws_instance.blax | sed -n '/public_ip[^_]/ s/.*"\([^"]*\)"/\1/p')
## aws --region eu-central-1 ec2 describe-instances
##

