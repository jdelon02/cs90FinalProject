provider "aws" {
  region = terraform.workspace == "default" ? "us-east-1" : "us-east-2"
}

# module "s3-bucket" {
#   source  = "terraform-aws-modules/s3-bucket/aws"
#   version = "4.2.2"
#   bucket = "delong-jeremy-cscie90"
# }