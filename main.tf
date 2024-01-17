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

resource "aws_launch_configuration" "EC2_Instance" {
  image_id        = "ami-0fe8bec493a81c7da"
  security_groups = [aws_security_group.instance.id] // referencing to the security group we are using

  instance_type = "t3.micro"
  user_data     = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.port_number} &
              EOF

  //-- Lifecycle --//
  # Required when using a launch configuration with an ASG as it does the following:
  // 1-it creates a new instance
  // 2-update any references that were pointing at the old resource to point to the replacement 
  // 3- deletes the old instance
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ASG_example" {
  launch_configuration = aws_launch_configuration.EC2_Instance.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  target_group_arns    = [aws_lb_target_group.asg.arn]
  health_check_type    = "ELB"

  min_size = 2
  max_size = 4

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "instance" { //To allow the EC2 Instance to receive traffic on port 8080, we need to create security group
  name = "terraform-example-instance"
  ingress {
    from_port   = var.port_number
    to_port     = var.port_number
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "port_number" {
  description = "The port number the server is listening on"
  type        = number
  default     = 8080
}

# output "public_ip" {
#   value       = aws_instance.EC2_first_Instance.public_ip
#   description = "The public IP address of the web server"

# }

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

//-- Load Balancer --//
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "alb" {
  name = "terraform-security-alb"
  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-group"
  port     = var.port_number
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

output "alb_dns_name" {
  value       = aws_lb.example
  description = "The domain name of the load balancer"
}