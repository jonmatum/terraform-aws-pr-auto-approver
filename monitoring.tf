# --- SNS Topic ---

resource "aws_sns_topic" "alerts" {
  count = var.monitoring_enabled ? 1 : 0
  name  = "${var.name}-alerts"
  tags  = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.monitoring_enabled && var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- Alarms ---

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.monitoring_enabled ? 1 : 0
  alarm_name          = "${var.name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda errors exceeded 5 in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count               = var.monitoring_enabled ? 1 : 0
  alarm_name          = "${var.name}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Lambda throttled more than 3 times in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count               = var.monitoring_enabled ? 1 : 0
  alarm_name          = "${var.name}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.bedrock_enabled ? 90000 : 20000
  alarm_description   = "Lambda average duration exceeded threshold"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  count               = var.monitoring_enabled ? 1 : 0
  alarm_name          = "${var.name}-apigw-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "API Gateway 5xx errors exceeded 5 in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  dimensions = {
    ApiId = aws_apigatewayv2_api.this.id
  }
  tags = var.tags
}

# --- Budget (Bedrock) ---

resource "aws_budgets_budget" "bedrock" {
  count        = var.monitoring_enabled && var.bedrock_enabled ? 1 : 0
  name         = "${var.name}-bedrock-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.bedrock_monthly_budget)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Bedrock"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
  }
}

# --- Dashboard ---

resource "aws_cloudwatch_dashboard" "this" {
  count          = var.monitoring_enabled ? 1 : 0
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = concat([
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "Lambda Invocations & Errors"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.this.function_name],
            [".", "Errors", ".", "."],
            [".", "Throttles", ".", "."],
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "Lambda Duration"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.this.function_name, { stat = "Average" }],
            ["...", { stat = "p99" }],
          ]
          period = 300
          region = data.aws_region.current.name
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "API Gateway Requests"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.this.id],
            [".", "5xx", ".", "."],
            [".", "4xx", ".", "."],
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "Lambda Concurrent Executions"
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", aws_lambda_function.this.function_name],
          ]
          period = 300
          stat   = "Maximum"
          region = data.aws_region.current.name
        }
      },
      ],
      var.bedrock_enabled ? [
        {
          type   = "metric"
          x      = 0
          y      = 12
          width  = 24
          height = 6
          properties = {
            title = "Bedrock Invocations"
            metrics = [
              ["AWS/Bedrock", "Invocations", "ModelId", var.bedrock_model_id],
              [".", "InvocationLatency", ".", ".", { stat = "Average" }],
            ]
            period = 300
            stat   = "Sum"
            region = data.aws_region.current.name
          }
        },
    ] : [])
  })
}

data "aws_region" "current" {}
