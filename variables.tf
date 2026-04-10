variable "name" {
  type        = string
  default     = "pr-auto-approver"
  description = "Name prefix for all resources"
}
variable "github_app_id" {
  type        = string
  description = "GitHub App ID"
}
variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "GitHub App private key PEM format"
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
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
