//Get ami id
data "aws_ami" "ubuntu" {
  owners = ["099720109477"]
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

//Get random port numbers for outline and ovpn
locals {
  port_pool = range(49152, 65536)
  port_strings = [ for p in local.port_pool : tostring(p) ]
}

resource "random_shuffle" "vpn_ports" {
  input = local.port_strings
  result_count = 3

  keepers = {
    instance_id = aws_instance.vpn-factory-server.id
  }
}

//VPC & Networking
resource "aws_vpc" "vpn-factory-vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "vpn-factory-vpc"
  }
}

resource "aws_subnet" "vpn-factory-subnet" {
  vpc_id = aws_vpc.vpn-factory-vpc.id
  cidr_block = var.vpc_cidr
  map_public_ip_on_launch = true
  tags = {
    Name = "vpn-factory-subnet"
  }
}

resource "aws_internet_gateway" "vpn-factory-igw" {
  vpc_id = aws_vpc.vpn-factory-vpc.id
  tags = {
    Name = "vpn-factory-igw"
  }
}

resource "aws_route_table" "vpn-factory-rtb" {
  vpc_id = aws_vpc.vpn-factory-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpn-factory-igw.id
  }
  tags = {
    Name = "vpn-factory-rtb"
  }
}

resource "aws_route_table_association" "vpn-factory-rtb-asso" {
  subnet_id = aws_subnet.vpn-factory-subnet.id
  route_table_id = aws_route_table.vpn-factory-rtb.id
}

resource "aws_security_group" "vpn-factory-sg" {
  name = "vpn-factory-sg"
  description = "SG for VPN server"
  vpc_id = aws_vpc.vpn-factory-vpc.id
  tags = {
    Name = "vpn-factory-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh-ing" {
  security_group_id = aws_security_group.vpn-factory-sg.id
  ip_protocol = "tcp"
  from_port = 22
  to_port = 22
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow-all-eg" {
  security_group_id = aws_security_group.vpn-factory-sg.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

//Ingress rules for randomized ports
resource "aws_vpc_security_group_ingress_rule" "vpn_ingress" {
  count = 6

  security_group_id = aws_security_group.vpn-factory-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  
  ip_protocol = count.index % 2 == 0 ? "tcp" : "udp"

  from_port = random_shuffle.vpn_ports.result[floor(count.index / 2)]
  to_port   = random_shuffle.vpn_ports.result[floor(count.index / 2)]
}

//EC2 Instance
resource "aws_instance" "vpn-factory-server" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.vpn-factory-subnet.id
  vpc_security_group_ids = [aws_security_group.vpn-factory-sg.id]
  key_name = var.keypair_name
  tags = {
    Name = "vpn-factory-server"
  }
  lifecycle {
    ignore_changes = [ami]
  }
}
