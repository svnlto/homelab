variable "mikrotik_api_url" {
  type = string
}

variable "mikrotik_username" {
  type      = string
  sensitive = true
}

variable "mikrotik_password" {
  type      = string
  sensitive = true
}

variable "pihole_ip" {
  type = string
}
