provider "aws" {
  region = "us-east-1"
  access_key = "<your_access_key>"
  secret_key = "<you_secret_access_key>"
}

variable "myvar" {
  description = "AZ value"
  type = string
}

#1. Create vpc
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "terra-vpc"
  }
}

#2. Create IGW
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id  
  tags = {
    Name = "terra-igw"
  }
}

#3. Create custome RT
resource "aws_route_table" "my_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "terra-rt"
  }
}

#4. Create a subnet
resource "aws_subnet" "subnet_1" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = var.myvar

  tags = {
    Name = "terra-subnet"
  }
}

#5. Associate the subnet with the RT
resource "aws_route_table_association" "rt_as" {
  subnet_id = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.my_rt.id
}

#6. Create SG to allow port 22,80,443
resource "aws_security_group" "my_sg" {
  name = "terra-sg"
  description = "Allow TLS inbpond traffic"
  vpc_id = aws_vpc.my_vpc.id

  ingress = [ {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "SSH for ec2"
    from_port = 22
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    protocol = "tcp"
    security_groups = []
    self = false
    to_port = 22
  }, {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "HTTP for ec2"
    from_port = 80
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    protocol = "tcp"
    security_groups = []
    self = false
    to_port = 80
  }, {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "HTTPS for ec2"
    from_port = 443
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    protocol = "tcp"
    security_groups = []
    self = false
    to_port = 443
  } ]
  
  egress = [ {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = ""
    from_port = 0
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    protocol = "-1"
    security_groups = []
    self = false
    to_port = 0
  } ]
  tags = {
    Name = "terra-sg"
  }
}

#7. Create elastic network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "my_eni" {
  subnet_id = aws_subnet.subnet_1.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.my_sg.id]

  tags = {
    Name = "terra-eni"
  }
}

#8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "my_eip" {
  vpc = true
  network_interface = aws_network_interface.my_eni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.my_igw
  ]
  
  tags = {
    Name = "terra-eip"
  }
}

#9. Create Ubuntu server and install/enable apache2
resource "aws_instance" "my_ec2" {
  ami = "ami-09d56f8956ab235b3"
  instance_type = "t2.micro"
  availability_zone = var.myvar
  key_name = "terra-project"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.my_eni.id
  }

  user_data = <<-EOF
              #! /bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo stsyemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "terra-ec2"
  }
}

#To print properties of resources on console
output "ec2-private-ip" {
  value = aws_instance.my_ec2.private_ip
}

output "eni-public-ip" {
  value = aws_network_interface.my_eni.private_ip
}