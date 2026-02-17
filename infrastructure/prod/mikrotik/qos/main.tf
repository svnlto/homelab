# =============================================================================
# QoS: Traffic shaping for WAN (Queue Tree with Mangle Marking)
#
# Prioritizes interactive traffic (DNS, SSH, ICMP) over bulk downloads
# (arr stack) while allowing bulk to burst to full speed when idle.
#
# Flow:
#   1. Connection marking (prerouting) — classify new connections
#   2. Packet marking (forward) — stamp packets with direction-aware marks
#   3. Queue trees (global) — HTB shaping with priority scheduling
# =============================================================================

# --- Address list for bulk hosts ---

resource "routeros_ip_firewall_addr_list" "bulk_hosts" {
  for_each = toset(var.bulk_hosts)

  list    = "qos-bulk"
  address = each.value
  comment = "QoS bulk traffic host"
}

# --- Connection marking (prerouting chain, new connections only) ---
# Order matters: priority rules first, then bulk. Unmarked = normal.

resource "routeros_ip_firewall_mangle" "mark_conn_dns_udp" {
  chain               = "prerouting"
  action              = "mark-connection"
  new_connection_mark = "priority"
  protocol            = "udp"
  dst_port            = "53"
  connection_state    = "new"
  passthrough         = false
  comment             = "QoS: mark DNS (UDP) connections as priority"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_conn_dns_tcp" {
  chain               = "prerouting"
  action              = "mark-connection"
  new_connection_mark = "priority"
  protocol            = "tcp"
  dst_port            = "53"
  connection_state    = "new"
  passthrough         = false
  comment             = "QoS: mark DNS (TCP) connections as priority"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_conn_ssh" {
  chain               = "prerouting"
  action              = "mark-connection"
  new_connection_mark = "priority"
  protocol            = "tcp"
  dst_port            = "22"
  connection_state    = "new"
  passthrough         = false
  comment             = "QoS: mark SSH connections as priority"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_conn_icmp" {
  chain               = "prerouting"
  action              = "mark-connection"
  new_connection_mark = "priority"
  protocol            = "icmp"
  connection_state    = "new"
  passthrough         = false
  comment             = "QoS: mark ICMP connections as priority"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_conn_bulk_src" {
  chain               = "prerouting"
  action              = "mark-connection"
  new_connection_mark = "bulk"
  src_address_list    = "qos-bulk"
  connection_state    = "new"
  passthrough         = false
  comment             = "QoS: mark bulk host connections (source) as bulk"

  depends_on = [routeros_ip_firewall_addr_list.bulk_hosts]

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_conn_bulk_dst" {
  chain               = "prerouting"
  action              = "mark-connection"
  new_connection_mark = "bulk"
  dst_address_list    = "qos-bulk"
  connection_state    = "new"
  passthrough         = false
  comment             = "QoS: mark bulk host connections (destination) as bulk"

  depends_on = [routeros_ip_firewall_addr_list.bulk_hosts]

  lifecycle { create_before_destroy = true }
}

# --- Packet marking (forward chain, direction-aware via WAN interface) ---
# Separate marks for download (in from WAN) and upload (out to WAN)
# so queue trees can shape each direction independently.

resource "routeros_ip_firewall_mangle" "mark_pkt_priority_download" {
  chain           = "forward"
  action          = "mark-packet"
  new_packet_mark = "priority-download"
  connection_mark = "priority"
  in_interface    = var.wan_interface
  passthrough     = false
  comment         = "QoS: mark priority download packets"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_pkt_priority_upload" {
  chain           = "forward"
  action          = "mark-packet"
  new_packet_mark = "priority-upload"
  connection_mark = "priority"
  out_interface   = var.wan_interface
  passthrough     = false
  comment         = "QoS: mark priority upload packets"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_pkt_bulk_download" {
  chain           = "forward"
  action          = "mark-packet"
  new_packet_mark = "bulk-download"
  connection_mark = "bulk"
  in_interface    = var.wan_interface
  passthrough     = false
  comment         = "QoS: mark bulk download packets"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_pkt_bulk_upload" {
  chain           = "forward"
  action          = "mark-packet"
  new_packet_mark = "bulk-upload"
  connection_mark = "bulk"
  out_interface   = var.wan_interface
  passthrough     = false
  comment         = "QoS: mark bulk upload packets"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_pkt_normal_download" {
  chain           = "forward"
  action          = "mark-packet"
  new_packet_mark = "normal-download"
  connection_mark = "no-mark"
  in_interface    = var.wan_interface
  passthrough     = false
  comment         = "QoS: mark normal download packets"

  lifecycle { create_before_destroy = true }
}

resource "routeros_ip_firewall_mangle" "mark_pkt_normal_upload" {
  chain           = "forward"
  action          = "mark-packet"
  new_packet_mark = "normal-upload"
  connection_mark = "no-mark"
  out_interface   = var.wan_interface
  passthrough     = false
  comment         = "QoS: mark normal upload packets"

  lifecycle { create_before_destroy = true }
}

# --- Mangle rule ordering ---

resource "routeros_move_items" "mangle_rules" {
  resource_path = "/ip/firewall/mangle"
  sequence = [
    # Connection marking (prerouting) — priority before bulk
    routeros_ip_firewall_mangle.mark_conn_dns_udp.id,
    routeros_ip_firewall_mangle.mark_conn_dns_tcp.id,
    routeros_ip_firewall_mangle.mark_conn_ssh.id,
    routeros_ip_firewall_mangle.mark_conn_icmp.id,
    routeros_ip_firewall_mangle.mark_conn_bulk_src.id,
    routeros_ip_firewall_mangle.mark_conn_bulk_dst.id,
    # Packet marking (forward) — download then upload per class
    routeros_ip_firewall_mangle.mark_pkt_priority_download.id,
    routeros_ip_firewall_mangle.mark_pkt_priority_upload.id,
    routeros_ip_firewall_mangle.mark_pkt_bulk_download.id,
    routeros_ip_firewall_mangle.mark_pkt_bulk_upload.id,
    routeros_ip_firewall_mangle.mark_pkt_normal_download.id,
    routeros_ip_firewall_mangle.mark_pkt_normal_upload.id,
  ]

  depends_on = [
    routeros_ip_firewall_mangle.mark_conn_dns_udp,
    routeros_ip_firewall_mangle.mark_conn_dns_tcp,
    routeros_ip_firewall_mangle.mark_conn_ssh,
    routeros_ip_firewall_mangle.mark_conn_icmp,
    routeros_ip_firewall_mangle.mark_conn_bulk_src,
    routeros_ip_firewall_mangle.mark_conn_bulk_dst,
    routeros_ip_firewall_mangle.mark_pkt_priority_download,
    routeros_ip_firewall_mangle.mark_pkt_priority_upload,
    routeros_ip_firewall_mangle.mark_pkt_bulk_download,
    routeros_ip_firewall_mangle.mark_pkt_bulk_upload,
    routeros_ip_firewall_mangle.mark_pkt_normal_download,
    routeros_ip_firewall_mangle.mark_pkt_normal_upload,
  ]
}

# =============================================================================
# Queue Trees — HTB hierarchy on global parent
#
# Download (95M total):  priority 20M guaranteed, normal 50M, bulk 10M
# Upload (40M total):    priority 10M guaranteed, normal 20M, bulk 5M
#
# All child queues can burst to parent max_limit when bandwidth is available.
# Priority 1 = highest, 8 = lowest in RouterOS.
# =============================================================================

# --- Download hierarchy ---

resource "routeros_queue_tree" "download_parent" {
  name      = "download"
  parent    = "global"
  max_limit = var.download_limit
  comment   = "QoS: WAN download shaping"
}

resource "routeros_queue_tree" "download_priority" {
  name        = "download-priority"
  parent      = routeros_queue_tree.download_parent.name
  packet_mark = ["priority-download"]
  priority    = 1
  limit_at    = "20M"
  max_limit   = var.download_limit
  comment     = "QoS: priority download (DNS, SSH, ICMP)"
}

resource "routeros_queue_tree" "download_normal" {
  name        = "download-normal"
  parent      = routeros_queue_tree.download_parent.name
  packet_mark = ["normal-download"]
  priority    = 4
  limit_at    = "50M"
  max_limit   = var.download_limit
  comment     = "QoS: normal download traffic"
}

resource "routeros_queue_tree" "download_bulk" {
  name        = "download-bulk"
  parent      = routeros_queue_tree.download_parent.name
  packet_mark = ["bulk-download"]
  priority    = 8
  limit_at    = "10M"
  max_limit   = var.download_limit
  comment     = "QoS: bulk download (arr stack)"
}

# --- Upload hierarchy ---

resource "routeros_queue_tree" "upload_parent" {
  name      = "upload"
  parent    = "global"
  max_limit = var.upload_limit
  comment   = "QoS: WAN upload shaping"
}

resource "routeros_queue_tree" "upload_priority" {
  name        = "upload-priority"
  parent      = routeros_queue_tree.upload_parent.name
  packet_mark = ["priority-upload"]
  priority    = 1
  limit_at    = "10M"
  max_limit   = var.upload_limit
  comment     = "QoS: priority upload (DNS, SSH, ICMP)"
}

resource "routeros_queue_tree" "upload_normal" {
  name        = "upload-normal"
  parent      = routeros_queue_tree.upload_parent.name
  packet_mark = ["normal-upload"]
  priority    = 4
  limit_at    = "20M"
  max_limit   = var.upload_limit
  comment     = "QoS: normal upload traffic"
}

resource "routeros_queue_tree" "upload_bulk" {
  name        = "upload-bulk"
  parent      = routeros_queue_tree.upload_parent.name
  packet_mark = ["bulk-upload"]
  priority    = 8
  limit_at    = "5M"
  max_limit   = var.upload_limit
  comment     = "QoS: bulk upload (arr stack)"
}
