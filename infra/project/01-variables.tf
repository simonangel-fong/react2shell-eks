# variables.tf

# ##############################
# cloudflare
# ##############################
variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permission on the zone"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id for arguswatcher.net"
  type        = string
}

# ##############################
# terraform backend
# ##############################
variable "tf_state_bucket" {
  description = "S3 bucket holding this stack's Terraform state"
  type        = string
}

variable "tf_state_key" {
  description = "State object key within the backend bucket"
  type        = string
}
