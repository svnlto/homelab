output "download_queues" {
  value = {
    parent   = routeros_queue_tree.download_parent.name
    priority = routeros_queue_tree.download_priority.name
    normal   = routeros_queue_tree.download_normal.name
    bulk     = routeros_queue_tree.download_bulk.name
  }
  description = "Download queue tree names"
}

output "upload_queues" {
  value = {
    parent   = routeros_queue_tree.upload_parent.name
    priority = routeros_queue_tree.upload_priority.name
    normal   = routeros_queue_tree.upload_normal.name
    bulk     = routeros_queue_tree.upload_bulk.name
  }
  description = "Upload queue tree names"
}
