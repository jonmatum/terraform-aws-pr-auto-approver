# terraform-aws-pr-auto-approver

Terraform module that deploys a GitHub App PR auto-approver to AWS Lambda behind API Gateway, with optional AI code review via Amazon Bedrock.

## Architecture

```
GitHub App webhook → API Gateway (HTTP) → Lambda (Probot) → Secrets Manager
                                                ↓
                                          [Bedrock AI Review]
                                                ↓
                                          GitHub API (approve / request changes)
```

## Usage

### Basic (auto-approve after CI passes)

```hcl
module "approver" {
  source  = "jonmatum/pr-auto-approver/aws"
  version = "~> 1.3"

  github_app_id          = "123456"
  github_app_private_key = file("private-key.pem")
  github_webhook_secret  = var.webhook_secret
  allowed_authors        = "your-username"
  lambda_zip_path        = "./lambda.zip"
}
```

### With Bedrock AI Review + PAT Approval

```hcl
module "approver" {
  source  = "jonmatum/pr-auto-approver/aws"
  version = "~> 1.3"

  github_app_id          = "123456"
  github_app_private_key = file("private-key.pem")
  github_webhook_secret  = var.webhook_secret
  allowed_authors        = "your-username"
  lambda_zip_path        = "./lambda.zip"

  bedrock_enabled    = true
  approval_token     = var.approval_token
  monitoring_enabled = true
  alert_email        = "you@example.com"
}
```

## Approval Modes

| Mode | How | Branch Protection |
|------|-----|-------------------|
| **App token** (default) | Bot approves as GitHub App | ❌ Doesn't count on Free plan |
| **PAT token** (recommended) | Bot approves as a real user | ✅ Counts toward required reviews |

To use PAT mode, create a classic GitHub PAT with `repo` scope from a second account, add that account as a collaborator with write access, and pass the token via `approval_token`.

## Security

- All secrets stored in AWS Secrets Manager (private key, webhook secret, approval token)
- Lambda env vars contain only Secrets Manager ARNs, never raw values
- IAM scoped to specific secrets only
- API Gateway throttling (burst: 10, rate: 5 req/s)
- Webhook signature verified by Probot on every request

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name prefix for all resources | `string` | `"pr-auto-approver"` | no |
| github_app_id | GitHub App ID | `string` | n/a | yes |
| github_app_private_key | GitHub App private key (PEM) | `string` | n/a | yes |
| github_webhook_secret | Webhook secret | `string` | n/a | yes |
| allowed_authors | Comma-separated usernames | `string` | `""` | no |
| lambda_zip_path | Path to Lambda zip | `string` | n/a | yes |
| approval_token | GitHub PAT for approvals | `string` | `""` | no |
| bedrock_enabled | Enable AI code review | `bool` | `false` | no |
| bedrock_model_id | Bedrock model ID | `string` | `"us.anthropic.claude-3-5-haiku-20241022-v1:0"` | no |
| monitoring_enabled | Enable CloudWatch dashboard/alarms | `bool` | `false` | no |
| alert_email | Email for alarm notifications | `string` | `""` | no |
| bedrock_monthly_budget | Monthly Bedrock spend threshold (USD) | `number` | `50` | no |
| tags | Tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| webhook_url | Set this as your GitHub App webhook URL |
| lambda_function_name | Lambda function name |
| lambda_function_arn | Lambda function ARN |
| api_gateway_id | API Gateway ID |
| api_gateway_endpoint | API Gateway base URL |
| sns_topic_arn | SNS topic ARN (when monitoring enabled) |
| dashboard_url | CloudWatch dashboard URL (when monitoring enabled) |

## License

MIT
