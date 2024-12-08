/**
 * @Author: Jeremy DeLong
 * @Date: 2024-12-07 12:00:10
 * @Desc:  VPC/IGW/Load Balancer/NAT Terraform Plan
 *
 * Steps:
 * 1. Create VPC.
 * 2. Create Route Table for VPC.
 * 3. Create an Internet Gateway.
 * 4. Build route and route table to internet
 * 5. Create a NAT.
 * 6. Create a route table, and build route to internet gateway.
 * 7. Create a natg elastic IP for nat.
 * 8. Create a route table, and build route to internet gateway.
 */

#Create VPC
resource "aws_vpc" "vpc_master" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${terraform.workspace}-vpc"
  }
}

#Create a route table for VPC
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc_master.id
  depends_on = [
    aws_vpc.vpc_master
  ]
  tags = {
    Name = "${terraform.workspace}-route-table"
  }
}

#Create an IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_master.id
  depends_on = [
    aws_route_table.public_route_table
  ]
  tags = {
    Name = "${terraform.workspace}-igw"
  }
}

#Build a route to the internet
resource "aws_route" "public_internet_gateway" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
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

#Create public subnet
resource "aws_subnet" "public_subnet" {
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.1.0/24"

  tags = {
    Name = "${terraform.workspace}-subnet"
  }
}

#Associate our public_subnet with the route to the IGW
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

#Create SG for allowing TCP/22 from anywhere, THIS IS FOR TESTING ONLY
resource "aws_security_group" "pub-sg" {
  name        = "${terraform.workspace}-pub-sg"
  description = "Allow SSH/HTTP/HTTPS"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "${terraform.workspace}-securitygroup"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.pub-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.pub-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.pub-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_ipv4" {
  security_group_id = aws_security_group.pub-sg.id
  cidr_ipv4       = "0.0.0.0/0"
  ip_protocol       = "-1"
}



################
# @TODO: Not sure if this is needed.
################


# @TODO: Not sure if this should be pub or priv.
# Creating an Elastic IP for the NAT Gateway!
# resource "aws_eip" "natg-elasticip" {
#   depends_on = [
#     aws_route_table_association.public
#   ]
# #   vpc_id      = aws_vpc.vpc_master.id
# }

# @TODO: Not sure if this should be pub or priv.
# Creating an Route Table Association of the NAT Gateway route
# resource "aws_route_table_association" "natg_route_table_association" {
#   depends_on = [
#     aws_route_table.natg_route_table
#   ]

#   subnet_id      = aws_subnet.private_subnet.id

#   route_table_id = aws_route_table.natg_route_table.id
# }