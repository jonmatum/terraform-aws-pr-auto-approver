# terraform-aws-pr-auto-approver

Terraform module that deploys a GitHub App PR auto-approver to AWS Lambda behind API Gateway, with optional AI code review via Amazon Bedrock and CloudWatch monitoring.

## Architecture

```
GitHub App webhook → API Gateway (HTTP) → Lambda (Probot) → Secrets Manager
                                                ↓
                                          [Bedrock AI Review]
                                                ↓
                                          GitHub API (approve / request changes)
```

## Resources Created

| Resource | Purpose |
|----------|---------|
| AWS Lambda | Runs the Probot app |
| API Gateway v2 (HTTP) | Receives GitHub webhooks |
| Secrets Manager (2 secrets) | Stores private key + webhook secret |
| IAM Role + Policy | Least-privilege (logs, secrets, optionally Bedrock) |
| CloudWatch Log Group | Lambda logs, 14-day retention |
| CloudWatch Dashboard | Metrics visualization (optional) |
| CloudWatch Alarms (4) | Error/throttle/duration/5xx alerts (optional) |
| SNS Topic + Email | Alarm notifications (optional) |
| AWS Budget | Bedrock spend alerts (optional) |

## Usage

### Basic (auto-approve after CI passes)

```hcl
module "approver" {
  source = "github.com/jonmatum/terraform-aws-pr-auto-approver?ref=v1.2.0"

  github_app_id          = "123456"
  github_app_private_key = file("private-key.pem")
  github_webhook_secret  = var.webhook_secret
  allowed_authors        = "your-username"
  lambda_zip_path        = "./lambda.zip"
}
```

### With Bedrock AI Review + Monitoring

```hcl
module "approver" {
  source = "github.com/jonmatum/terraform-aws-pr-auto-approver?ref=v1.2.0"

  github_app_id          = "123456"
  github_app_private_key = file("private-key.pem")
  github_webhook_secret  = var.webhook_secret
  allowed_authors        = "your-username"
  lambda_zip_path        = "./lambda.zip"

  bedrock_enabled        = true
  monitoring_enabled     = true
  alert_email            = "you@example.com"
  bedrock_monthly_budget = 50
}
```

### Bedrock AI Review

When `bedrock_enabled = true`:
- Lambda timeout increases to 120s, memory to 256MB
- IAM role gets `bedrock:InvokeModel` scoped to the specified model
- The bot reviews PR diffs for bugs, security vulnerabilities, and missing error handling
- Clean code → auto-approved ✅
- Issues found → inline review comments + changes requested ❌

### Monitoring

When `monitoring_enabled = true`:
- CloudWatch Dashboard with Lambda, API Gateway, and Bedrock metrics
- Alarms: Lambda errors (>5/5min), throttles (>3/5min), high duration, API Gateway 5xx
- SNS email alerts
- Bedrock monthly budget alerts at 80% and 100%

## Security

- **Secrets are never stored in Lambda environment variables.** The Lambda reads `PRIVATE_KEY` and `WEBHOOK_SECRET` from Secrets Manager at runtime on cold start, then caches them in memory.
- Lambda env vars contain only Secrets Manager ARNs.
- IAM policy is scoped to only the two specific secrets.
- API Gateway has throttling (burst: 10, rate: 5 req/s).
- Webhook signature is verified by Probot on every request.

## Prerequisites

1. Create a GitHub App with Pull requests (Read & Write) and Checks (Read) permissions, subscribed to Pull request and Check suite events
2. Build Lambda zip from [pr-auto-approver](https://github.com/jonmatum/pr-auto-approver):
   ```bash
   npm ci && zip -r lambda.zip index.js lambda.js review.js secrets.js node_modules package.json
   ```
3. (Optional) Enable the Bedrock model in your AWS account via the Bedrock console

> **Important:** Use the GitHub App's built-in webhook to deliver events. Do NOT create separate repo-level webhooks — they lack the `installation` key that Probot requires for authentication.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name prefix for all resources | `string` | `"pr-auto-approver"` | no |
| github_app_id | GitHub App ID | `string` | n/a | yes |
| github_app_private_key | GitHub App private key (PEM) | `string` | n/a | yes |
| github_webhook_secret | Webhook secret | `string` | n/a | yes |
| allowed_authors | Comma-separated usernames to auto-approve | `string` | `""` | no |
| lambda_zip_path | Path to Lambda deployment zip | `string` | n/a | yes |
| bedrock_enabled | Enable AI code review via Bedrock | `bool` | `false` | no |
| bedrock_model_id | Bedrock model ID | `string` | `"anthropic.claude-3-haiku-20240307-v1:0"` | no |
| monitoring_enabled | Enable CloudWatch dashboard and alarms | `bool` | `false` | no |
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

## Related

- [pr-auto-approver](https://github.com/jonmatum/pr-auto-approver) — Lambda app code
- [terraform-github-pr-auto-approver](https://github.com/jonmatum/terraform-github-pr-auto-approver) — GitHub webhooks module (optional)

## License

MIT
