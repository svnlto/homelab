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

variable "access_ports" {
  type = map(object({
    interface = string
    pvid      = number
    comment   = string
  }))
}

variable "trunk_ports" {
  type = map(object({
    interface = string
    comment   = string
  }))
}

variable "wan_interface" {
  type        = string
  description = "WAN interface name (standalone, not in bridge)"
}

variable "wan_address" {
  type        = string
  description = "WAN IP address with CIDR (e.g. 192.168.8.2/24)"
}

variable "wan_gateway" {
  type        = string
  description = "WAN default gateway IP"
}
