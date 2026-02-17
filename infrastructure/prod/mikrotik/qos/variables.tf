variable "wan_interface" {
  description = "WAN interface name (e.g. ether1)"
  type        = string
}

variable "download_limit" {
  description = "Max download rate for WAN shaping (e.g. 95M)"
  type        = string
}

variable "upload_limit" {
  description = "Max upload rate for WAN shaping (e.g. 40M)"
  type        = string
}

variable "bulk_hosts" {
  description = "IP addresses of hosts to classify as bulk traffic (e.g. arr stack)"
  type        = list(string)
}
