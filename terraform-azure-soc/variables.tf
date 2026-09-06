variable "sendgrid_api_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SendGrid API key for the SOC notification email (free tier: 100 emails/day). Leave empty to deploy without email."
}

variable "soc_email_to" {
  type        = string
  default     = "soc-team@contoso.com"
  description = "Recipient address for SOC email notifications."
}

variable "soc_email_from" {
  type        = string
  default     = "soc@contoso.com"
  description = "Verified Sender address in SendGrid."
}