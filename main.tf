resource "aws_secretsmanager_secret" "private_key" {
  name       = "${var.name}-private-key"
  kms_key_id = var.kms_key_id
  tags       = var.tags
}

resource "aws_secretsmanager_secret_version" "private_key" {
  secret_id     = aws_secretsmanager_secret.private_key.id
  secret_string = var.github_app_private_key
}

resource "aws_secretsmanager_secret" "webhook_secret" {
  name       = "${var.name}-webhook-secret"
  kms_key_id = var.kms_key_id
  tags       = var.tags
}

resource "aws_secretsmanager_secret_version" "webhook_secret" {
  secret_id     = aws_secretsmanager_secret.webhook_secret.id
  secret_string = var.github_webhook_secret
}

resource "aws_secretsmanager_secret" "approval_token" {
  count      = var.approval_token != "" ? 1 : 0
  name       = "${var.name}-approval-token"
  kms_key_id = var.kms_key_id
  tags       = var.tags
}

resource "aws_secretsmanager_secret_version" "approval_token" {
  count         = var.approval_token != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.approval_token[0].id
  secret_string = var.approval_token
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [aws_cloudwatch_log_group.lambda.arn, "${aws_cloudwatch_log_group.lambda.arn}:*"] #tfsec:ignore:aws-iam-no-policy-wildcards -- :* suffix required for log streams
  }

  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq.arn]
  }

  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = concat(
      [
        aws_secretsmanager_secret.private_key.arn,
        aws_secretsmanager_secret.webhook_secret.arn,
      ],
      var.approval_token != "" ? [aws_secretsmanager_secret.approval_token[0].arn] : []
    )
  }

  statement {
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.bedrock_enabled ? [1] : []
    content {
      actions   = ["bedrock:InvokeModel"]
      resources = ["arn:aws:bedrock:*:*:inference-profile/${var.bedrock_model_id}", "arn:aws:bedrock:*::foundation-model/*"]
    }
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = var.name
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

resource "aws_lambda_function" "this" {
  function_name    = var.name
  handler          = "lambda.handler"
  runtime          = "nodejs20.x"
  timeout          = var.bedrock_enabled ? 120 : 30
  memory_size      = var.bedrock_enabled ? 256 : 128
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  role             = aws_iam_role.lambda.arn

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = merge(
      {
        APP_ID                    = var.github_app_id
        PRIVATE_KEY_SECRET_ARN    = aws_secretsmanager_secret.private_key.arn
        WEBHOOK_SECRET_SECRET_ARN = aws_secretsmanager_secret.webhook_secret.arn
        ALLOWED_AUTHORS           = var.allowed_authors
      },
      var.bedrock_enabled ? {
        BEDROCK_ENABLED  = "true"
        BEDROCK_MODEL_ID = var.bedrock_model_id
      } : {},
      var.approval_token != "" ? {
        APPROVAL_TOKEN_SECRET_ARN = aws_secretsmanager_secret.approval_token[0].arn
      } : {},
      var.auto_collaborator != "" ? {
        AUTO_COLLABORATOR = var.auto_collaborator
      } : {}
    )
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 14
  kms_key_id        = var.kms_key_id
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = 14
  kms_key_id        = var.kms_key_id
  tags              = var.tags
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"
  tags          = var.tags
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
  tags        = var.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }
}

resource "aws_apigatewayv2_integration" "this" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /api/github/webhooks"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_lambda_permission" "apigw" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
