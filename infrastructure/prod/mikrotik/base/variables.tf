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

variable "bridge_name" {
  type = string
}

variable "vlans" {
  type = map(object({
    id          = number
    name        = string
    subnet      = string
    gateway     = string
    description = string
  }))
}

variable "interfaces" {
  type = map(string)
}
