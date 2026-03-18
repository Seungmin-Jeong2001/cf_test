variable "cf_api_token" { type = string }
variable "cf_account_id" { type = string }
variable "cf_zone_id" { type = string }

variable "ssh_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks to allow SSH access"
  default     = ["0.0.0.0/0"] # Defaulting to 0.0.0.0/0 for now, but making it configurable.
}