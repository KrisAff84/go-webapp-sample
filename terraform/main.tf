/* Deploys an EC2 instance with Jenkins installed, as well as an S3 Bucket
for Jenkins artifacts, along with all of the necessary security groups and
permissions.
*/

#####################################
# Provider
#####################################

provider "aws" {
  region = var.aws_region
}

#####################################
# Data - Get Default VPC
#####################################

data "aws_vpc" "default" {
  default = true
}

#####################################
# EC2 Instance
#####################################

resource "aws_instance" "jenkins_server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.jenkins_server_sg.id]
  key_name               = var.key_pair
  tags = {
    Name = "Jenkins_Server"
  }
  user_data            = <<EOF
#!/bin/bash
apt update -y
apt install openjdk-17-jre -y
wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y 
apt-get install jenkins -y
systemctl start jenkins
systemctl enable jenkins
EOF
  iam_instance_profile = aws_iam_instance_profile.ec2_bucket_profile.name
}

#####################################
# Instance Security Group
#####################################

resource "aws_security_group" "jenkins_server_sg" {
  name        = "web_server_inbound"
  description = "Allow SSH from MyIP and access to port 8080"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    description = "Allow 8080 from the Internet"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH from my IP"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#####################################
# S3 Bucket
#####################################

resource "aws_s3_bucket" "jenkins_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

#####################################
# Instance Profile - Gives Instance
# Read/Write Access to S3 Bucket
#####################################

resource "aws_iam_role_policy" "policy" {
  name = "ec2_jenkins_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PerformBucketActions",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ],
        "Resource" : [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"

        ]
      }
    ]
  })
  role = aws_iam_role.ec2_bucket_role.name
}

resource "aws_iam_role" "ec2_bucket_role" {
  name = "ec2_bucket_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_bucket_profile" {
  name = "ec2_bucket_profile"
  role = aws_iam_role.ec2_bucket_role.name
}

#####################################
# Key Pair
#####################################

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.key.private_key_pem
  filename = "${var.key_pair}.pem"

  # Sets permissions on key and adds it to ssh-agent when terraform apply is run
  provisioner "local-exec" {
    command = "chmod 400 ${var.key_pair}.pem && ssh-add ${var.key_pair}.pem"
  }
}
resource "aws_key_pair" "key" {
  key_name   = var.key_pair
  public_key = tls_private_key.key.public_key_openssh
}

#####################################
# Outputs
#####################################

output "Jenkins_web_access" {
  value = "${aws_instance.jenkins_server.public_ip}:8080"
}

output "Jenkins_ssh_access" {
  value = "ssh ubuntu@${aws_instance.jenkins_server.public_ip}"
}