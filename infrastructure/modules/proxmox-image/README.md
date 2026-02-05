# Proxmox Image Module

Generic reusable module for downloading and uploading ISO/disk images to Proxmox storage.

## Purpose

This module provides a unified way to:

1. Download images from any URL (with optional decompression)
2. Upload local images directly
3. Store images persistently in Proxmox for reuse across VM deployments

## Why This Approach?

- **No SSH required**: Uses local download + Terraform upload (no SSH keys needed)
- **Persistent storage**: Images persist across VM/cluster destroy/apply cycles
- **Reusable**: Same image can be used by multiple VMs/clusters
- **Generic**: Works with any OS (Talos, TrueNAS, Ubuntu, etc.)
- **Flexible**: Supports compressed downloads or local files

## Usage Examples

### Talos Linux Disk Image (Compressed)

```hcl
module "talos_image" {
  source = "../../modules/proxmox-image"

  download_url        = "https://factory.talos.dev/image/dc7b152.../v1.12.2/nocloud-amd64.raw.xz"
  image_name          = "talos-v1.12.2-nocloud-amd64.raw"
  compression_format  = "xz"

  proxmox_node        = "din"
  datastore_id        = "local"
  content_type        = "iso"
  proxmox_filename    = "talos-v1.12.2-nocloud.img"
}
```

### TrueNAS ISO (No Compression)

```hcl
module "truenas_iso" {
  source = "../../modules/proxmox-image"

  download_url        = "https://download.truenas.com/TrueNAS-SCALE-Dragonfish-24.10.0.iso"
  image_name          = "TrueNAS-SCALE-Dragonfish-24.10.0.iso"
  compression_format  = "none"

  proxmox_node        = "din"
  datastore_id        = "local"
  content_type        = "iso"
  proxmox_filename    = "truenas-scale-24.10.0.iso"
}
```

### Local File Upload

```hcl
module "custom_image" {
  source = "../../modules/proxmox-image"

  local_file_path     = "/path/to/custom-image.iso"
  image_name          = "custom-image.iso"

  proxmox_node        = "din"
  datastore_id        = "local"
  content_type        = "iso"
  proxmox_filename    = "custom-v1.0.iso"
}
```

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | -------- |
| `download_url` | URL to download image from | string | `""` | no* |
| `local_file_path` | Local file path (if not downloading) | string | `""` | no* |
| `image_name` | Base name for image (without compression ext) | string | - | yes |
| `compression_format` | Compression format (xz, gz, none) | string | `"none"` | no |
| `proxmox_node` | Target Proxmox node | string | - | yes |
| `datastore_id` | Proxmox datastore for storage | string | - | yes |
| `content_type` | Proxmox content type (iso, vztmpl) | string | `"iso"` | no |
| `proxmox_filename` | Filename in Proxmox storage | string | - | yes |

\* Either `download_url` or `local_file_path` must be provided

## Outputs

| Name | Description |
| ---- | ----------- |
| `image_id` | Proxmox file ID for use in VM configuration |
| `image_name` | Base name of uploaded image |
| `proxmox_filename` | Filename in Proxmox storage |

## Notes

- Downloaded images are stored in `<deployment-dir>/.images/` (should be git-ignored)
- Requires `curl` for downloads, `xz` for xz compression, `gunzip` for gz compression
- Images only re-download if `download_url` or `image_name` changes
- For disk images, use `content_type = "iso"` (Proxmox requirement)
- The module creates the `.images` directory automatically

## Dependencies

Local utilities required:

- `curl` - For downloading images
- `xz` - For xz-compressed images
- `gunzip` - For gzip-compressed images
