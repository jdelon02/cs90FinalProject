/**
 * @Author: Jeremy DeLong
 * @Date: 2024-12-07 12:00:10
 * @Desc:  aurora Terraform Plan
 */

# Create private subnet
resource "aws_subnet" "private_aurora_subnet" {
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.3.0/24"

  tags = {
    Name = "${terraform.workspace}-private-aurora-subnet"
  }
}

# Create a subnet group for Aurora
resource "aws_db_subnet_group" "private_aurora_subnet_group" {
  name = "private-aurora-subnet-group"
  subnet_ids = [aws_subnet.private_aurora_subnet.id]
}

# Create Aurora cluster in private subnet
resource "aws_rds_cluster" "drupal_default" {
  cluster_identifier      = "${terraform.workspace}-aurora-cluster-drupal"
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.03.2"
  availability_zones      = [
        element(data.aws_availability_zones.azs.names, 0)
    ]
  database_name           = "${terraform.workspace}-aurora-drupal"
  master_username         = "foo"
  master_password         = "must_be_eight_characters"
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"

  db_subnet_group_name = aws_subnet.private_aurora_subnet.id
}

# sec grp + rules
# @TODO: Need to change this to only allow 3306.
# Create SG for allowing Certain ports from anywhere for private subnet
resource "aws_security_group" "private-aurora-sg" {
  name        = "${terraform.workspace}-private-aurora-sg"
  description = "Allow 3306"
  vpc_id      = aws_vpc.vpc_master.id
  tags = {
    Name = "${terraform.workspace}-privatesecuritygroup"
  }
}

# @TODO: Think CIDR is wrong for this, I only want to allow aurora -> webservers.
resource "aws_vpc_security_group_ingress_rule" "allow_private_auroraconn" {
  security_group_id = aws_security_group.private-aurora-sg.id
  cidr_ipv4         = aws_subnet.private_aurora_subnet.cidr_block
  from_port         = 3306
  to_port           = 3306
  ip_protocol       = "tcp"
}

# @TODO: This is wrong I think.
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_private_ipv4" {
  security_group_id = aws_security_group.private-aurora-sg.id
  cidr_ipv4         = aws_subnet.private_aurora_subnet.cidr_block
  ip_protocol       = "-1"
}


