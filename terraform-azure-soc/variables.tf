variable "smtp2go_api_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SMTP2GO API key for the SOC notification email (free tier: 1,000 emails/month, 200/day). Leave empty to deploy without email."
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