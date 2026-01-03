terraform {
  backend "s3" {
    bucket         = "prod-REPLACE_ME-tfstate-bucket"
    key            = "line-odoo/prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "prod-REPLACE_ME-tflock"
    encrypt        = true
  }
}
