provider "aws" {
  region = "us-east-1"
}

module "pr_auto_approver" {
  source = "../../"

  github_app_id          = var.github_app_id
  github_app_private_key = var.github_app_private_key
  github_webhook_secret  = var.github_webhook_secret
  allowed_authors        = "your-username"
  lambda_zip_path        = "./lambda.zip"
}

output "webhook_url" {
  value = module.pr_auto_approver.webhook_url
}
