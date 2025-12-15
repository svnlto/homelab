variable "ubuntu_url" {
  type        = string
  description = "URL to download Ubuntu Server ARM64 image for Raspberry Pi"
  default     = "https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.3-preinstalled-server-arm64+raspi.img.xz"
}

variable "hostname" {
  type        = string
  description = "Hostname for the Raspberry Pi"
  default     = "rpi-pihole"
}

source "arm" "raspberry-pi" {
  file_urls             = [var.ubuntu_url]
  file_checksum         = "9bb1799cee8965e6df0234c1c879dd35be1d87afe39b84951f278b6bd0433e56"
  file_checksum_type    = "sha256"
  file_target_extension = "xz"
  file_unarchive_cmd    = ["xz", "-d", "$ARCHIVE_PATH"]

  image_build_method = "resize"
  image_path         = "output/rpi-pihole.img"
  image_size         = "8G"
  image_type         = "dos"

  image_partitions {
    name         = "boot"
    type         = "c"
    start_sector = "8192"
    filesystem   = "vfat"
    size         = "512M"
    mountpoint   = "/boot"
  }

  image_partitions {
    name         = "root"
    type         = "83"
    start_sector = "532480"
    filesystem   = "ext4"
    size         = "0"
    mountpoint   = "/"
  }

  image_chroot_env             = ["PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"]
  qemu_binary_source_path      = "/usr/bin/qemu-aarch64-static"
  qemu_binary_destination_path = "/usr/bin/qemu-aarch64-static"
}

build {
  sources = ["source.arm.raspberry-pi"]

  # Fix DNS resolution in chroot
  provisioner "shell" {
    inline = [
      "rm -f /etc/resolv.conf",
      "echo 'nameserver 1.1.1.1' > /etc/resolv.conf",
      "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"
    ]
  }

  # Enable SSH
  provisioner "shell" {
    inline = [
      "systemctl enable ssh"
    ]
  }

  # Set hostname
  provisioner "shell" {
    environment_vars = ["HOSTNAME=${var.hostname}"]
    inline = [
      "echo $HOSTNAME > /etc/hostname",
      "sed -i \"s/127.0.1.1.*/127.0.1.1\\t$HOSTNAME/\" /etc/hosts"
    ]
  }

  # System update and install prerequisites
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "apt-get update",
      "apt-get upgrade -y",
      "apt-get install -y python3 python3-pip curl vim git htop ntp"
    ]
  }

  # Install Docker (required by Ansible docker_compose_v2 module)
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sh get-docker.sh",
      "systemctl enable docker",
      "rm get-docker.sh",
      "apt-get install -y docker-compose-plugin"
    ]
  }

  # Install Ansible
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "apt-get install -y ansible"
    ]
  }

  # Copy Ansible files to image
  provisioner "shell" {
    inline = [
      "mkdir -p /tmp/ansible/playbooks/roles"
    ]
  }

  # Copy role files
  provisioner "file" {
    source      = "/ansible/roles/pihole"
    destination = "/tmp/ansible/playbooks/roles/"
  }

  # Copy playbook
  provisioner "file" {
    source      = "/ansible/playbooks/packer-pihole.yml"
    destination = "/tmp/ansible/playbooks/packer-pihole.yml"
  }

  # Run Ansible playbook locally in chroot
  provisioner "shell" {
    inline = [
      "cd /tmp/ansible/playbooks",
      "ansible-playbook -i localhost, -c local packer-pihole.yml --extra-vars 'pihole_webpassword=changeme pihole_ipv4_address=192.168.1.2 packer_build=true'"
    ]
  }

  # Cleanup Ansible files
  provisioner "shell" {
    inline = [
      "rm -rf /tmp/ansible",
      "apt-get purge -y ansible",
      "apt-get autoremove -y"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "apt-get autoremove -y",
      "apt-get autoclean -y",
      "apt-get clean",
      "rm -rf /var/lib/apt/lists/*"
    ]
  }

  post-processor "manifest" {
    output     = "manifest-pihole.json"
    strip_path = true
  }
}
