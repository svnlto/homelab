variable "download_url" {
  description = "URL to download the image from (leave empty if using local file)"
  type        = string
  default     = ""
}

variable "local_file_path" {
  description = "Local file path if not downloading (mutually exclusive with download_url)"
  type        = string
  default     = ""
}

variable "image_name" {
  description = "Base name for the downloaded image (without compression extension)"
  type        = string
}

variable "compression_format" {
  description = "Compression format of downloaded image (xz, gz, or none)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["xz", "gz", "none"], var.compression_format)
    error_message = "Compression format must be one of: xz, gz, none"
  }
}

variable "proxmox_node" {
  description = "Target Proxmox node name"
  type        = string
}

variable "datastore_id" {
  description = "Proxmox datastore ID for image storage"
  type        = string
}

variable "content_type" {
  description = "Proxmox content type (iso, vztmpl, etc.)"
  type        = string
  default     = "iso"

  validation {
    condition     = contains(["iso", "vztmpl"], var.content_type)
    error_message = "Content type must be one of: iso, vztmpl"
  }
}

variable "proxmox_filename" {
  description = "Filename for the image in Proxmox storage"
  type        = string
}
