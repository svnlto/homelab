output "instance_ip" {
  description = "Public IPv4 address of the photo relay Linode"
  value       = tolist(linode_instance.photo_relay.ipv4)[0]
}

output "instance_label" {
  description = "Label of the photo relay Linode"
  value       = linode_instance.photo_relay.label
}
