variable "acl_tags" {
  description = "Tag owners mapping (tag name without 'tag:' prefix → list of owners)"
  type        = map(list(string))
  default = {
    "k8s"        = ["autogroup:admin"]
    "dumper-src" = ["autogroup:admin"]
  }
}

variable "mullvad_exit_node_ip" {
  description = "Tailscale IP of the Mullvad exit node"
  type        = string
}

variable "k8s_auto_approved_routes" {
  description = "Subnet routes auto-approved for tag:k8s devices"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}
