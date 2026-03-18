variable "cf_api_token" { type = string }
variable "cf_account_id" { type = string }
variable "cf_zone_id" { type = string }

variable "ssh_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks to allow SSH access"
  default     = ["0.0.0.0/0"]
}

variable "gcp_project_id" { type = string }
variable "gcp_region" {
  type    = string
  default = "asia-northeast3" # Seoul Region
}
variable "gcp_zone" {
  type    = string
  default = "asia-northeast3-c"
}
variable "gcp_credentials" {
  type        = string
  description = "GCP Service Account JSON Key"
  sensitive   = true
}
