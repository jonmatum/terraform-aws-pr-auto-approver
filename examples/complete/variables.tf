variable "github_app_id" {
  type = string
}
variable "github_app_private_key" {
  type      = string
  sensitive = true
}
variable "github_webhook_secret" {
  type      = string
  sensitive = true
}
