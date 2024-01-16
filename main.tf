terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region                   = "eu-north-1"
  shared_config_files      = ["C:/Users/Jeffar/.aws/config"]
  shared_credentials_files = ["C:/Users/Jeffar/.aws/credentials"]
}

resource "aws_instance" "EC2_first_Instance" {
  ami                    = "ami-0fe8bec493a81c7da"
  vpc_security_group_ids = [aws_security_group.instance.id] // referencing to the security group we are using

  instance_type = "t3.micro"
  user_data     = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF

  user_data_replace_on_change = true
  tags = {
    Name = "My-AWS-Instance"
  }

}


resource "aws_security_group" "instance" { //To allow the EC2 Instance to receive traffic on port 8080, we need to create security group
  name = "terraform-example-instance"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

