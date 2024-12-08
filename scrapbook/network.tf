#Create VPC
resource "aws_vpc" "vpc_master" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${terraform.workspace}-vpc"
  }

}

#Get all available AZ's in VPC for master region
data "aws_availability_zones" "azs" {
  state = "available"
}

#Create public subnet
resource "aws_subnet" "public_subnet" {
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.1.0/24"

  tags = {
    Name = "${terraform.workspace}-subnet"
  }
}

#Create an IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_master.id

  tags = {
    Name = "${terraform.workspace}-igw"
  }
}

#Create a route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc_master.id

  tags = {
    Name = "${terraform.workspace}-route-table"
  }
}
#Build a route to the internet
resource "aws_route" "public_internet_gateway" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

#Associate our public_subnet with the route to the IGW
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

#Create SG for allowing TCP/22 from anywhere, THIS IS FOR TESTING ONLY
resource "aws_security_group" "sg" {
  name        = "${terraform.workspace}-sg"
  description = "Allow TCP/22"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "${terraform.workspace}-securitygroup"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_ipv4" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4       = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#Create private subnet
resource "aws_subnet" "private_subnet" {
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name = "${terraform.workspace}-private-subnet"
  }
}

# Creating an Elastic IP for the NAT Gateway!
resource "aws_eip" "natg-elasticip" {
  depends_on = [
    aws_route_table_association.public
  ]
#   vpc_id      = aws_vpc.vpc_master.id
}

# Need to create a NATG - Then associate that with the IGW
resource "aws_nat_gateway" "natg" {
  connectivity_type = "private"
  subnet_id     = aws_subnet.public_subnet.id
  #allocation_id = aws_eip.natg-elasticip.id
  tags = {
    Name = "NATG"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Creating a Route Table for the Nat Gateway!
resource "aws_route_table" "natg_route_table" {
  depends_on = [
    aws_nat_gateway.natg
  ]

  vpc_id = aws_vpc.vpc_master.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natg.id
  }

  tags = {
    Name = "Route Table for NAT Gateway"
  }

}

# Creating an Route Table Association of the NAT Gateway route
resource "aws_route_table_association" "natg_route_table_association" {
  depends_on = [
    aws_route_table.natg_route_table
  ]

  subnet_id      = aws_subnet.private_subnet.id

  route_table_id = aws_route_table.natg_route_table.id
}

#Create SG for allowing Certain ports from anywhere for private subnet
resource "aws_security_group" "private-sg" {
  name        = "${terraform.workspace}-private-sg"
  description = "Allow SSH, HTTP, HTTPS, PING"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "${terraform.workspace}-privatesecuritygroup"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_private_ssh" {
  security_group_id = aws_security_group.private-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "allow_private_http" {
  security_group_id = aws_security_group.private-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "allow_private_https" {
  security_group_id = aws_security_group.private-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_private_ipv4" {
  security_group_id = aws_security_group.private-sg.id
  cidr_ipv4       = "0.0.0.0/0"
  ip_protocol       = "-1"
}