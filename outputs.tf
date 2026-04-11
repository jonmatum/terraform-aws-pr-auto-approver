output "webhook_url" {
  description = "Full webhook URL for GitHub App configuration"
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/api/github/webhooks"
}
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}
output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}
output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.this.id
}
output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.this.api_endpoint
}
output "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  value       = var.monitoring_enabled ? aws_sns_topic.alerts[0].arn : null
}
output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = var.monitoring_enabled ? "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${var.name}" : null
}
output "dlq_arn" {
  description = "Dead letter queue ARN for failed webhook processing"
  value       = aws_sqs_queue.dlq.arn
}
