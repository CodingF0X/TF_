terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.31.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region  = "eu-north-1"
  shared_config_files      = ["C:/Users/Jeffar/.aws/config"]
  shared_credentials_files = ["C:/Users/Jeffar/.aws/credentials"]
}

resource "aws_instance" "EC2_first_Instance" {
  ami =  "ami-0fe8bec493a81c7da"
  instance_type = "t3.micro"
  tags = {
    name = "My-AWS-Instance"
  }
  
}

