terraform {
  backend "s3" {
    bucket         = "terraform-url-shortener-state"
    key            = "url-shortener/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
