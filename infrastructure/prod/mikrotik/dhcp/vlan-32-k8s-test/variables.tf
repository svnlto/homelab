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

variable "vlan_name" {
  type = string
}

variable "vlan_id" {
  type = number
}

variable "vlan_interface" {
  type = string
}

variable "subnet" {
  type = string
}

variable "gateway" {
  type = string
}

variable "dhcp_start" {
  type = string
}

variable "dhcp_end" {
  type = string
}

variable "dhcp_lease" {
  type = string
}

variable "dns_servers" {
  type = list(string)
}
