resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-url-shortener-state"
  versioning {
    enabled = true
  }
}

# Create DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_lock" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
