# terraform-aws-pr-auto-approver

Terraform module that deploys a GitHub App PR auto-approver to AWS Lambda behind API Gateway.

## Architecture

GitHub PR Event → API Gateway (HTTP) → Lambda (Probot) → GitHub API (approve)

## Resources Created
- AWS Lambda
- API Gateway v2 (HTTP)
- Secrets Manager (private key + webhook secret)
- IAM Role (least-privilege)
- CloudWatch Log Group (14-day retention)

## Usage

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

module "approver_github" {
  source  = "jonmatum/pr-auto-approver/github"
  version = "~> 1.0"

  webhook_url           = module.approver_infra.webhook_url
  webhook_secret        = var.webhook_secret
  github_repositories   = ["my-repo"]
}
```

## Prerequisites
1. Create a GitHub App with Pull requests (Read & Write) and Checks (Read) permissions, subscribed to Pull request and Check suite events
2. Build Lambda zip from pr-auto-approver repo: `npm ci && zip -r lambda.zip index.js lambda.js node_modules package.json`

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name prefix for all resources | `string` | `"pr-auto-approver"` | no |
| github_app_id | GitHub App ID | `string` | n/a | yes |
| github_app_private_key | GitHub App private key PEM format | `string` | n/a | yes |
| github_webhook_secret | GitHub App webhook secret | `string` | n/a | yes |
| allowed_authors | Comma-separated GitHub usernames to auto-approve | `string` | `""` | no |
| lambda_zip_path | Path to the Lambda deployment zip | `string` | n/a | yes |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| webhook_url | Full webhook URL for GitHub App configuration |
| lambda_function_name | Name of the Lambda function |
| lambda_function_arn | ARN of the Lambda function |
| api_gateway_id | ID of the API Gateway |
| api_gateway_endpoint | API Gateway endpoint URL |

## Related
- [pr-auto-approver](https://github.com/jonmatum/pr-auto-approver)
- [terraform-github-pr-auto-approver](https://github.com/jonmatum/terraform-github-pr-auto-approver)
