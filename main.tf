/**
 * @Author: Jeremy DeLong
 * @Date: 2024-12-07 12:00:10
 * @Desc:  Main Terraform Plan
 */

provider "aws" {
  region = terraform.workspace == "default" ? "us-east-1" : "us-east-2"
}

#Get all available AZ's in VPC for master region
data "aws_availability_zones" "azs" {
  state = "available"
}
