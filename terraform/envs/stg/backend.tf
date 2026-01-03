terraform {
  backend "s3" {
    bucket         = "stg-REPLACE_ME-tfstate-bucket"
    key            = "line-odoo/stg/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "stg-REPLACE_ME-tflock"
    encrypt        = true
  }
}
