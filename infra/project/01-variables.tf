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
