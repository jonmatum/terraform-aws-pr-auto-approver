# Changelog

## [1.6.0](https://github.com/jonmatum/terraform-aws-pr-auto-approver/compare/v1.5.0...v1.6.0) (2026-04-11)


### Features

* add auto_collaborator variable ([#5](https://github.com/jonmatum/terraform-aws-pr-auto-approver/issues/5)) ([2568ee9](https://github.com/jonmatum/terraform-aws-pr-auto-approver/commit/2568ee93836984167bf3361249c1411d425e7f92))

## [1.3.0] - 2026-04-11

### Added
- Optional `approval_token` for PAT-based approvals that satisfy branch protection on GitHub Free plan
- Approval token stored in Secrets Manager
- Claude 3.5 Haiku as default Bedrock model
- IAM support for Bedrock inference profiles

### Removed
- `auto_merge` variable (approve only, user clicks merge)

## [1.2.1] - 2026-04-10

### Fixed
- Replaced deprecated `data.aws_region.current.name` with `.id` in CloudWatch dashboard

## [1.2.0] - 2026-04-10

### Changed
- Restored Secrets Manager integration for production-grade secret handling
- Lambda reads PRIVATE_KEY and WEBHOOK_SECRET from Secrets Manager at runtime via ARN
- Secrets are never stored in Lambda environment variables

## [1.1.0] - 2026-04-10

### Changed
- Lambda env vars now pass secrets directly instead of Secrets Manager ARNs (Probot requires WEBHOOK_SECRET and PRIVATE_KEY at startup before user code runs)
- Removed reserved_concurrent_executions to avoid conflicts with low-limit AWS accounts

### Added
- Optional CloudWatch monitoring (dashboard, alarms, SNS alerts, Bedrock budget)

## [1.0.0] - 2026-04-10

### Added
- Initial release
- AWS Lambda function with Probot for GitHub App PR auto-approval
- API Gateway v2 (HTTP) for webhook ingestion
- Secrets Manager for private key and webhook secret
- Optional Amazon Bedrock AI code review
- CloudWatch Log Group with 14-day retention
- Least-privilege IAM with dynamic Bedrock permissions
