# based off TF docs example: https://github.com/hashicorp/learn-terraform-aws-asg
# uses Ubuntu Jammy as EC2 AMI
terraform {
  cloud {
    organization = "go-cloud-engineers"

    workspaces {
      name = "github-aws-auto-scaling-web-app"
    }
  }
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      source = "GoCloudEngineersAutoscalingDemo"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name = "autoscaling-vpc"
  cidr = "10.0.0.0/16"

  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "terramino" {
  name_prefix     = "learn-terraform-aws-asg-"
  image_id        = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  user_data       = file("bootstrap.sh") #replace with your own bootstrap file name
  key_name        = "amunoz_admin" #replace with your own key name
  security_groups = [aws_security_group.terramino_instance.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "terramino" {
  name                 = "terramino"
  min_size             = 1
  max_size             = 10
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.terramino.name
  vpc_zone_identifier  = module.vpc.public_subnets

  tag {
    key                 = "Name"
    value               = "asg-GoCloudEngineers-asg-demo"
    propagate_at_launch = true
  }
}

resource "aws_lb" "terramino" {
  name               = "alb-learn-asg-terramino-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terramino_lb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "terramino" {
  load_balancer_arn = aws_lb.terramino.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terramino.arn
  }
}

resource "aws_lb_target_group" "terramino" {
  name     = "learn-asg-terramino"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}


resource "aws_autoscaling_attachment" "terramino" {
  autoscaling_group_name = aws_autoscaling_group.terramino.id
  lb_target_group_arn   = aws_lb_target_group.terramino.arn
}

resource "aws_security_group" "terramino_instance" {
  name = "learn-asg-terramino-instance"
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.terramino_lb.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    #security_groups = [aws_security_group.terramino_lb.id]
    cidr_blocks      = ["0.0.0.0/0"] #outbound access to the world to download patches
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "terramino_lb" {
  name = "learn-asg-terramino-lb"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}   
