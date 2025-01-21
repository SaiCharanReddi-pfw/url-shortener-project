# Data Resource for Caller Identity
data "aws_caller_identity" "current" {}


# DynamoDB Table for URL Shortener
resource "aws_dynamodb_table" "url_shortener" {
  name         = "url-shortener"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = "URL Shortener"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "url-shortener-lambda-role"
  assume_role_policy = jsonencode({
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": [
					"lambda.amazonaws.com"
				]
			},
			"Action": "sts:AssumeRole"
		}
	]
})
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.url_shortener.arn
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "url_shortener_lambda" {
  function_name = "url-shortener-lambda"
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_role.arn

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.url_shortener.name
    }
  }

  tags = {
    Project = "URL Shortener"
  }
}

# Permission to Lambda to Allow API Gateway to Invoke POST Method
resource "aws_lambda_permission" "apigateway_invoke_post" {
  statement_id  = "AllowExecutionFromAPIGatewayForPost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.url_shortener_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:eu-west-2:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.url_shortener_api.id}/*/*/"
}

# Permission to Lambda to Allow API Gateway to Invoke GET Method
resource "aws_lambda_permission" "apigateway_invoke_get" {
  statement_id  = "AllowExecutionFromAPIGatewayForGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.url_shortener_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:eu-west-2:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.url_shortener_api.id}/*/GET/{id}"
}

# API Gateway
resource "aws_api_gateway_rest_api" "url_shortener_api" {
  name        = "url-shortener-api"
  description = "API Gateway for URL Shortener"
}

# API Gateway Resource
resource "aws_api_gateway_resource" "url_resource" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  parent_id   = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  path_part   = "{id}"
}

# POST Method for Short URL Creation
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id   = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
}

# GET Method for Redirect
resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id   = aws_api_gateway_resource.url_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integration for POST Method
resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id             = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  http_method             = aws_api_gateway_method.post_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.url_shortener_lambda.invoke_arn
}

# Integration for GET Method
resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id             = aws_api_gateway_resource.url_resource.id
  http_method             = aws_api_gateway_method.get_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "GET"
  uri                     = aws_lambda_function.url_shortener_lambda.invoke_arn
}

# Deploy API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  depends_on = [
    aws_api_gateway_integration.post_integration,
    aws_api_gateway_integration.get_integration
  ]
}

# IAM Role for API Gateway Logging
resource "aws_iam_role" "api_gateway_logging_role" {
  name = "APIGatewayCloudWatchLogsRole"
  assume_role_policy = jsonencode({
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": [
					"apigateway.amazonaws.com"
				]
			},
			"Action": "sts:AssumeRole"
		}
	]
})
}

# IAM Policy for API Gateway Logging Role
resource "aws_iam_role_policy_attachment" "api_gateway_logging_policy" {
  role       = aws_iam_role.api_gateway_logging_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Associate IAM Role with API Gateway Account
resource "aws_api_gateway_account" "account_settings" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logging_role.arn
}

# API Gateway Stage with Logging
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id              = aws_api_gateway_deployment.api_deployment.id
  rest_api_id                = aws_api_gateway_rest_api.url_shortener_api.id
  stage_name                 = "prod"
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format          = "$context.requestId $context.identity.sourceIp $context.httpMethod $context.resourcePath $context.status $context.responseLength $context.requestTime"
  }

  depends_on = [aws_api_gateway_account.account_settings]
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/apigateway/url-shortener"
  retention_in_days = 14
}
