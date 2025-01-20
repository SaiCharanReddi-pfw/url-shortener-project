output "api_url" {
  value = "https://${aws_api_gateway_rest_api.url_shortener_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}"
}
