# Downloads and uploads ISO/disk images to Proxmox storage.

resource "null_resource" "download_image" {
  count = var.download_url != "" ? 1 : 0

  triggers = {
    download_url = var.download_url
    image_name   = var.image_name
    checksum     = var.checksum
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.root}/.images

      # Download the image
      echo "Downloading ${var.image_name} from ${var.download_url}..."
      if [ "${var.compression_format}" = "none" ]; then
        curl -fsSL "${var.download_url}" -o "${path.root}/.images/${var.image_name}"
      else
        curl -fsSL "${var.download_url}" -o "${path.root}/.images/${var.image_name}.${var.compression_format}"
      fi

      # Verify checksum (if provided)
      if [ -n "${var.checksum}" ]; then
        echo "Verifying SHA256 checksum..."
        if [ "${var.compression_format}" = "none" ]; then
          ACTUAL=$(shasum -a 256 "${path.root}/.images/${var.image_name}" | cut -d' ' -f1)
        else
          ACTUAL=$(shasum -a 256 "${path.root}/.images/${var.image_name}.${var.compression_format}" | cut -d' ' -f1)
        fi
        if [ "$ACTUAL" != "${var.checksum}" ]; then
          echo "ERROR: Checksum mismatch! Expected ${var.checksum}, got $ACTUAL"
          exit 1
        fi
        echo "Checksum verified."
      fi

      # Decompress if needed
      if [ "${var.compression_format}" = "xz" ]; then
        echo "Decompressing with xz..."
        xz -d -k -f "${path.root}/.images/${var.image_name}.${var.compression_format}"
      elif [ "${var.compression_format}" = "gz" ]; then
        echo "Decompressing with gunzip..."
        gunzip -k -f "${path.root}/.images/${var.image_name}.${var.compression_format}"
      fi
    EOT
  }
}

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
