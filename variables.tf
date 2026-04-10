variable "name" {
  type        = string
  default     = "pr-auto-approver"
  description = "Name prefix for all resources"

  validation {
    condition     = length(var.name) > 0
    error_message = "Name must not be empty"
  }
}

variable "github_app_id" {
  type        = string
  description = "GitHub App ID"

  validation {
    condition     = can(regex("^[0-9]+$", var.github_app_id))
    error_message = "GitHub App ID must be numeric"
  }
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "GitHub App private key PEM format"

  validation {
    condition     = startswith(var.github_app_private_key, "-----BEGIN")
    error_message = "Private key must be in PEM format"
  }
}

variable "github_webhook_secret" {
  type        = string
  sensitive   = true
  description = "GitHub App webhook secret"
}

variable "allowed_authors" {
  type        = string
  default     = ""
  description = "Comma-separated GitHub usernames to auto-approve"
}

variable "lambda_zip_path" {
  type        = string
  description = "Path to the Lambda deployment zip"
}

variable "bedrock_enabled" {
  type        = bool
  default     = false
  description = "Enable AI code review via Amazon Bedrock"
}

variable "bedrock_model_id" {
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
  description = "Bedrock model ID for AI review"

  validation {
    condition     = length(var.bedrock_model_id) > 0
    error_message = "Bedrock model ID must not be empty"
  }
}

variable "monitoring_enabled" {
  type        = bool
  default     = false
  description = "Enable CloudWatch dashboard and alarms"
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "Email address for alarm notifications (required if monitoring_enabled = true)"
}

variable "bedrock_monthly_budget" {
  type        = number
  default     = 50
  description = "Monthly Bedrock spend threshold in USD before alerting"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
