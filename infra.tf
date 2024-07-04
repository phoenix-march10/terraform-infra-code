terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

# Creating the VPC
resource "aws_vpc" "webapp-vpc" {
  cidr_block       = "10.10.0.0/16"

  tags = {
    Name = "Webapp-VPC"
  }
}

# Creating the 3 subnets
resource "aws_subnet" "webapp-subnet-2a" {
  vpc_id     = aws_vpc.webapp-vpc.id
  cidr_block = "10.10.0.0/24"
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "webapp-subnet-2a"
  }
}

resource "aws_subnet" "webapp-subnet-2b" {
  vpc_id     = aws_vpc.webapp-vpc.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "webapp-subnet-2b"
  }
}

resource "aws_subnet" "webapp-subnet-2c" {
  vpc_id     = aws_vpc.webapp-vpc.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "us-east-2c"

  tags = {
    Name = "webapp-subnet-2c"
  }
}

# Creating EC2 server/instance
resource "aws_instance" "webapp-instance-1" {
    ami = "ami-09040d770ffe2224f"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.webapp-subnet-2a.id
    key_name = aws_key_pair.webapp-key.id
    associate_public_ip_address = true
    vpc_security_group_ids = [aws_security_group.allow_22_80.id]
    user_data = filebase64("userdata.sh") # filebase64 will encode the content of userdata.sh

    tags = {
      Name = "Webapp-machine1"
    }
}

resource "aws_instance" "webapp-instance-2" {
    ami = "ami-09040d770ffe2224f"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.webapp-subnet-2b.id
    key_name = aws_key_pair.webapp-key.id
    associate_public_ip_address = true
    vpc_security_group_ids = [aws_security_group.allow_22_80.id]
    user_data = filebase64("userdata.sh") # filebase64 will encode the content of userdata.sh

    tags = {
      Name = "Webapp-machine2"
    }
}

resource "aws_key_pair" "webapp-key" {
  key_name   = "webapp-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkPcfXjWvObhbsGwkvLvsutZhoEmwuANi5xFqtn+dTKcWvy6f1dVDUD6Wt++Fxv2lsa0vyqhNkPK3OP9L61hl/myEWj3MbXK3nVdVECQhRbmjroUQ2IbHtDNw22vpCw8j/QI3bSla0GZOt/dBCsPGokbi7vVVH+7tDBackKYv7SoGrPLO5VoBzuBx8dZStcwiVVFKKjxmYvvriYwRsCkMf8qpKFj4XuHTZoyV3LHuhWk4/c3j+Ya3X+GFjkvhVrhMPxHJhsqu4ToRZ9PKv/w5Nfz9/SAQzucN9D6M6wCnatcC0ntdRWJ0bUs7P3Y204ELHLzg0bXs/CUk2Zs4mbzy7 kuhankavint@Kuhans-MacBook-Pro.local"
}

# create security group
resource "aws_security_group" "allow_22_80" {
  name        = "allow_22_80"
  description = "Allow TLS inbound traffic22 and 80"
  vpc_id      = aws_vpc.webapp-vpc.id

  tags = {
    Name = "allow_22_80"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_22" {
  security_group_id = aws_security_group.allow_22_80.id
  cidr_ipv4         = "0.0.0.0/0" # All people to login from port 22 to 22
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_80" {
  security_group_id = aws_security_group.allow_22_80.id
  cidr_ipv4         = "0.0.0.0/0" # All people to login from port 22 to 22
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_traffic_ipv4" {
  security_group_id = aws_security_group.allow_22_80.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports, no need to mention from_port and to_port with this single line
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_traffic_ipv6" {
  security_group_id = aws_security_group.allow_22_80.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Create Internet Gateway
resource "aws_internet_gateway" "webapp-igw" {
  vpc_id = aws_vpc.webapp-vpc.id

  tags = {
    Name = "Webapp-IGW"
  }
}

# Create Route Table 
resource "aws_route_table" "webapp-public-RT" {
  vpc_id = aws_vpc.webapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0" # all the traffic allows(public) and forwarded to the IGW
    gateway_id = aws_internet_gateway.webapp-igw.id
  }

  tags = {
    Name = "Webapp-public-RT"
  }
}

resource "aws_route_table" "webapp-private-RT" {
  vpc_id = aws_vpc.webapp-vpc.id

  tags = {
    Name = "Webapp-private-RT"
  }
}

# Attach Route table to the subnet
resource "aws_route_table_association" "RT_association_subnet_1_public" {
  subnet_id      = aws_subnet.webapp-subnet-2a.id
  route_table_id = aws_route_table.webapp-public-RT.id
}

resource "aws_route_table_association" "RT_association_subnet_2_public" {
  subnet_id      = aws_subnet.webapp-subnet-2b.id
  route_table_id = aws_route_table.webapp-public-RT.id
}

resource "aws_route_table_association" "RT_association_subnet_3_private" {
  subnet_id      = aws_subnet.webapp-subnet-2c.id
  route_table_id = aws_route_table.webapp-private-RT.id
}

# Create Target Group
resource "aws_lb_target_group" "webapp-target-group" {
  name     = "webapp-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.webapp-vpc.id
}

# Create Target Group attachment
resource "aws_lb_target_group_attachment" "webapp-target-group-attachment1" {
  target_group_arn = aws_lb_target_group.webapp-target-group.arn
  target_id        = aws_instance.webapp-instance-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "webapp-target-group-attachment2" {
  target_group_arn = aws_lb_target_group.webapp-target-group.arn
  target_id        = aws_instance.webapp-instance-2.id
  port             = 80
}

# Create Load Balancer
resource "aws_lb" "webapp-alb" {
  name               = "webapp-alb"
  internal           = false # false meaning, not internal use only, this load balancer should available over the internet, externally.
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_80.id] #check below security group configuratiin for LB
  subnets            = [aws_subnet.webapp-subnet-2a.id, aws_subnet.webapp-subnet-2b.id]

  tags = {
    Environment = "production"
  }
}

# create security group for load balancer
resource "aws_security_group" "allow_80" {
  name        = "allow_80"
  description = "Allow TLS inbound traffic 80"
  vpc_id      = aws_vpc.webapp-vpc.id

  tags = {
    Name = "allow_80"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_80_1" {
  security_group_id = aws_security_group.allow_80.id
  cidr_ipv4         = "0.0.0.0/0" # All people to login from port 80 to 80
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_traffic_ipv4_1" {
  security_group_id = aws_security_group.allow_80.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports, no need to mention from_port and to_port with this single line
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_traffic_ipv6_1" {
  security_group_id = aws_security_group.allow_80.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Create Listener
resource "aws_lb_listener" "webapp_listener" {
  load_balancer_arn = aws_lb.webapp-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp-target-group.arn
  }
}

# Create Launch Template
resource "aws_launch_template" "webapp_launch_template" {
  name = "webapp_launch_template"
  image_id = "ami-09040d770ffe2224f"
  instance_type = "t2.micro"
  key_name = aws_key_pair.webapp-key.id
  vpc_security_group_ids = [aws_security_group.allow_22_80.id]
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "webapp-machine-asg"
    }
  }

  user_data = filebase64("userdata.sh")
} 

# Create Auto Scaling Group
resource "aws_autoscaling_group" "webapp-asg" {
  #name_prefix = "webapp-asg-"
  vpc_zone_identifier = [aws_subnet.webapp-subnet-2a.id, aws_subnet.webapp-subnet-2b.id]
  desired_capacity   = 2
  max_size           = 5
  min_size           = 2
  target_group_arns = [aws_lb_target_group.webapp-target-group_2.arn]

  launch_template {
    id      = aws_launch_template.webapp_launch_template.id
    version = "$Latest"
  }
}

# Create ALB2 Target Group
resource "aws_lb_target_group" "webapp-target-group_2" {
  name     = "webapp-target-group-2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.webapp-vpc.id
}

# Create ALB2 Load Balancer
resource "aws_lb" "webapp-alb-2" {
  name               = "webapp-alb-2"
  internal           = false # false meaning, not internal use only, this load balancer should available over the internet, externally.
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_80.id] #check below security group configuratiin for LB
  subnets            = [aws_subnet.webapp-subnet-2a.id, aws_subnet.webapp-subnet-2b.id]

  tags = {
    Environment = "production"
  }
}

# Create Listener
resource "aws_lb_listener" "webapp_listener_2" {
  load_balancer_arn = aws_lb.webapp-alb-2.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp-target-group_2.arn
  }
}

# Create Target Tracking Policy
resource "aws_autoscaling_policy" "example" {
  autoscaling_group_name = aws_autoscaling_group.webapp-asg.name
  name                   = "webapp_policy"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    target_value = 60
    customized_metric_specification {
      metrics {
        label = "Get the queue size (the number of messages waiting to be processed)"
        id    = "m1"
        metric_stat {
          metric {
            namespace   = "AWS/SQS"
            metric_name = "ApproximateNumberOfMessagesVisible"
            dimensions {
              name  = "QueueName"
              value = "my-queue"
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "Get the group size (the number of InService instances)"
        id    = "m2"
        metric_stat {
          metric {
            namespace   = "AWS/AutoScaling"
            metric_name = "GroupInServiceInstances"
            dimensions {
              name  = "AutoScalingGroupName"
              value = "my-asg"
            }
          }
          stat = "Average"
        }
        return_data = false
      }
      metrics {
        label       = "Calculate the backlog per instance"
        id          = "e1"
        expression  = "m1 / m2"
        return_data = true
      }
    }
  }
}