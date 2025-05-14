# Root Terraform Project for 3-Tier Web App with Auto Scaling

# Provider Configuration
provider "aws" {
  region = "ap-south-1"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = "three-tier-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["ap-south-1a", "ap-south-1b"]

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  tags = {
    Project = "3tier"
  }
}

# Security Groups
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP"
  vpc_id      = module.vpc.vpc_id

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
}

resource "aws_security_group" "app_sg" {
  name   = "app-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Instance
resource "aws_db_subnet_group" "default" {
  name       = "rds-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
   
  username             = "admin"
  password             = "Admin1234!"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name = aws_db_subnet_group.default.name
}

# Web Tier - Launch Template
resource "aws_launch_template" "web_lt" {
  name_prefix   = "web-lt"
  image_id      = "ami-0af9569868786b23a" # Amazon Linux 2 AMI in ap-south-1
  instance_type = "t3.micro"
  key_name      = "key1" # Replace with your key pair

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.web_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx
              cat <<EOCONF > /etc/nginx/conf.d/app.conf
              server {
                  listen 80;
                  location / {
                      proxy_pass http://${aws_lb.app_alb.dns_name}:5000;
                  }
              }
              EOCONF
              systemctl restart nginx
              systemctl enable nginx
              EOF
  )
}

# Web Tier - Target Group
resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "instance"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# Web Tier - Load Balancer
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Web Tier - Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = module.vpc.private_subnets
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.web_tg.arn]
  tag {
    key                 = "Name"
    value               = "web-asg-instance"
    propagate_at_launch = true
  }
  health_check_type         = "EC2"
  health_check_grace_period = 300
}

# App Tier - Launch Template
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-lt"
  image_id      = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"
  key_name      = "key1"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              pip3 install flask pymysql
              cat <<EOF2 > /home/ec2-user/app.py
              from flask import Flask
              app = Flask(__name__)
              @app.route('/')
              def home():
                  return "<h1>App Tier - Flask API</h1>"
              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=5000)
              EOF2
              nohup python3 /home/ec2-user/app.py &
              EOF
  )
}

# App Tier - Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "instance"
  health_check {
    path                = "/"
    port                = "5000"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# App Tier - Internal Load Balancer
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = module.vpc.private_subnets
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "5000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# App Tier - Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = module.vpc.private_subnets
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.app_tg.arn]
  tag {
    key                 = "Name"
    value               = "app-asg-instance"
    propagate_at_launch = true
  }
  health_check_type         = "EC2"
  health_check_grace_period = 300
}

# Outputs
output "web_sg_id" {
  value = aws_security_group.web_sg.id
}

output "app_sg_id" {
  value = aws_security_group.app_sg.id
}

output "db_sg_id" {
  value = aws_security_group.db_sg.id
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "web_alb_dns" {
  value = aws_lb.web_alb.dns_name
}

output "app_alb_dns" {
  value = aws_lb.app_alb.dns_name
}

