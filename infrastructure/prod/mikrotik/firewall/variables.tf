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

variable "vlan_interfaces" {
  type = map(string)
}

variable "wan_interface" {
  type = string
}
