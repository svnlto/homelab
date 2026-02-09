# ==============================================================================
# Generic Proxmox Image Module
# Downloads and uploads ISO/disk images to Proxmox storage
# ==============================================================================

# ==============================================================================
# Download Image Locally (Optional - skip if using local file)
# ==============================================================================

resource "null_resource" "download_image" {
  count = var.download_url != "" ? 1 : 0

  triggers = {
    download_url = var.download_url
    image_name   = var.image_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.root}/.images

      # Download the image
      echo "Downloading ${var.image_name} from ${var.download_url}..."
      curl -fsSL "${var.download_url}" -o "${path.root}/.images/${var.image_name}.${var.compression_format}"

      # Decompress if needed
      if [ "${var.compression_format}" = "xz" ]; then
        echo "Decompressing with xz..."
        xz -d -k -f "${path.root}/.images/${var.image_name}.${var.compression_format}"
      elif [ "${var.compression_format}" = "gz" ]; then
        echo "Decompressing with gunzip..."
        gunzip -k -f "${path.root}/.images/${var.image_name}.${var.compression_format}"
      elif [ "${var.compression_format}" = "none" ]; then
        echo "No decompression needed."
        mv "${path.root}/.images/${var.image_name}.none" "${path.root}/.images/${var.image_name}"
      fi
    EOT
  }
}

# ==============================================================================
# Upload Image to Proxmox
# ==============================================================================

resource "proxmox_virtual_environment_file" "image" {
  datastore_id = var.datastore_id
  node_name    = var.proxmox_node
  content_type = var.content_type

  source_file {
    path      = var.download_url != "" ? "${path.root}/.images/${var.image_name}" : var.local_file_path
    file_name = var.proxmox_filename
  }

  depends_on = [null_resource.download_image]
}
