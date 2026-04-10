# terraform-aws-pr-auto-approver

Terraform module that deploys a GitHub App PR auto-approver to AWS Lambda behind API Gateway, with optional AI code review via Amazon Bedrock and optional CloudWatch monitoring.

## Architecture

```
GitHub PR Event → API Gateway (HTTP) → Lambda (Probot) → [Bedrock Review] → GitHub API
```

## Resources Created
- AWS Lambda
- API Gateway v2 (HTTP)
- Secrets Manager (private key + webhook secret)
- IAM Role (least-privilege, Bedrock permissions added only when enabled)
- CloudWatch Log Group (14-day retention)
- (Optional) CloudWatch Dashboard, Alarms, SNS Topic, Bedrock Budget

## Usage

### Basic (auto-approve after CI passes)

```hcl
module "approver_infra" {
  source  = "jonmatum/pr-auto-approver/aws"
  version = "~> 1.0"

  github_app_id          = "123456"
  github_app_private_key = file("private-key.pem")
  github_webhook_secret  = var.webhook_secret
  allowed_authors        = "your-username"
  lambda_zip_path        = "./lambda.zip"
}
```

### With Bedrock AI Review + Monitoring

```hcl
module "approver_infra" {
  source  = "jonmatum/pr-auto-approver/aws"
  version = "~> 1.0"

  github_app_id          = "123456"
  github_app_private_key = file("private-key.pem")
  github_webhook_secret  = var.webhook_secret
  allowed_authors        = "your-username"
  lambda_zip_path        = "./lambda.zip"

  bedrock_enabled        = true
  bedrock_model_id       = "anthropic.claude-3-haiku-20240307-v1:0"

  monitoring_enabled     = true
  alert_email            = "you@example.com"
  bedrock_monthly_budget = 50
}
```

### Monitoring Dashboard

When `monitoring_enabled = true`, the module creates:
- **CloudWatch Dashboard** with panels for Lambda invocations/errors/duration, API Gateway requests, concurrent executions, and Bedrock metrics (when enabled)
- **Alarms** for Lambda errors (>5/5min), throttles (>3/5min), high duration, and API Gateway 5xx errors
- **SNS Topic** with email subscription for alarm notifications
- **AWS Budget** (Bedrock only) with alerts at 80% and 100% of monthly threshold

## Prerequisites
1. Create a GitHub App with Pull requests (Read & Write) and Checks (Read) permissions, subscribed to Pull request and Check suite events
2. Build Lambda zip: `npm ci && zip -r lambda.zip index.js lambda.js review.js secrets.js node_modules package.json`
3. Lambda reads secrets from Secrets Manager at runtime via ARN — raw values are never stored in Lambda environment variables
4. (Optional) Enable the Bedrock model in your AWS account via the Bedrock console

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name prefix for all resources | `string` | `"pr-auto-approver"` | no |
| github_app_id | GitHub App ID | `string` | n/a | yes |
| github_app_private_key | GitHub App private key PEM format | `string` | n/a | yes |
| github_webhook_secret | GitHub App webhook secret | `string` | n/a | yes |
| allowed_authors | Comma-separated GitHub usernames to auto-approve | `string` | `""` | no |
| lambda_zip_path | Path to the Lambda deployment zip | `string` | n/a | yes |
| bedrock_enabled | Enable AI code review via Amazon Bedrock | `bool` | `false` | no |
| bedrock_model_id | Bedrock model ID for AI review | `string` | `"anthropic.claude-3-haiku-20240307-v1:0"` | no |
| monitoring_enabled | Enable CloudWatch dashboard and alarms | `bool` | `false` | no |
| alert_email | Email for alarm notifications | `string` | `""` | no |
| bedrock_monthly_budget | Monthly Bedrock spend threshold (USD) | `number` | `50` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| webhook_url | Full webhook URL for GitHub App configuration |
| lambda_function_name | Name of the Lambda function |
| lambda_function_arn | ARN of the Lambda function |
| api_gateway_id | ID of the API Gateway |
| api_gateway_endpoint | API Gateway endpoint URL |
| sns_topic_arn | SNS topic ARN (when monitoring enabled) |
| dashboard_url | CloudWatch dashboard URL (when monitoring enabled) |

## Related
- [pr-auto-approver](https://github.com/jonmatum/pr-auto-approver)
- [terraform-github-pr-auto-approver](https://github.com/jonmatum/terraform-github-pr-auto-approver)
