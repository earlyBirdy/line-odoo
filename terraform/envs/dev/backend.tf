terraform {
  backend "s3" {
    bucket         = "dev-REPLACE_ME-tfstate-bucket"
    key            = "line-odoo/dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "dev-REPLACE_ME-tflock"
    encrypt        = true
  }
}
