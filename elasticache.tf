/**
 * @Author: Jeremy DeLong
 * @Date: 2024-12-07 12:00:10
 * @Desc:  Elasticache Terraform Plan
 *
 * Plan:
 * 1. Create redis cluster
 * 2. Create private network.
 * 3. Create redis SG and rules.
 */

 #Create private subnet
resource "aws_subnet" "private_elasticache_subnet" {
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.2.0/24"
  tags = {
    Name = "${terraform.workspace}-private-elasticache-subnet"
  }
}

resource "aws_elasticache_subnet_group" "private_elasticache_subnet_group" {
  name       = "private_elasticache-subnet-group"
  subnet_ids = [aws_subnet.private_elasticache_subnet.id]
}

resource "aws_elasticache_cluster" "elasticache-cluster" {
  cluster_id           = "${terraform.workspace}-cluster-elasticache"
  engine               = "redis"
  node_type            = "cache.m4.large"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis3.2"
  engine_version       = "3.2.10"
  port                 = 6379
  security_group_ids = [aws_elasticache_subnet_group.private_elasticache_subnet_group.id]
}

#Create SG for allowing Certain ports from anywhere for private subnet
resource "aws_security_group" "private-elasticache-sg" {
  name        = "${terraform.workspace}-private-elasticache-sg"
  description = "Allow Elasticache Redis Ports"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "${terraform.workspace}-privatesg-elasticache"
  }
}

# @TODO: Think CIDR is wrong for this, I only want to allow redis -> webservers.
resource "aws_vpc_security_group_ingress_rule" "allow_private_elasticache" {
  security_group_id = aws_security_group.private-elasticache-sg.id
  cidr_ipv4         = aws_subnet.private_elasticache_subnet.cidr_block
  from_port         = aws_elasticache_cluster.elasticache-cluster.port
  to_port           = aws_elasticache_cluster.elasticache-cluster.port
  ip_protocol       = "tcp"
}

# @TODO: This is wrong I think.
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_elasticache_ipv4" {
  security_group_id = aws_security_group.private-elasticache-sg.id
  cidr_ipv4         = aws_subnet.private_elasticache_subnet.cidr_block
  from_port         = aws_elasticache_cluster.elasticache-cluster.port
  to_port           = aws_elasticache_cluster.elasticache-cluster.port
  ip_protocol       = "-1"
}