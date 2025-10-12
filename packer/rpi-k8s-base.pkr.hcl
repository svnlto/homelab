variable "ubuntu_url" {
  type        = string
  description = "URL to download Ubuntu Server ARM64 image for Raspberry Pi"
  default     = "https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.3-preinstalled-server-arm64+raspi.img.xz"
}

variable "k8s_version" {
  type        = string
  description = "Kubernetes version to install (major.minor format)"
  default     = "1.31"
}

source "arm" "raspberry-pi" {
  file_urls             = [var.ubuntu_url]
  file_checksum         = "9bb1799cee8965e6df0234c1c879dd35be1d87afe39b84951f278b6bd0433e56"
  file_checksum_type    = "sha256"
  file_target_extension = "xz"
  file_unarchive_cmd    = ["xz", "-d", "$ARCHIVE_PATH"]

  image_build_method = "resize"
  image_path         = "output-rpi-k8s/rpi-k8s-base.img"
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

  # Fix DNS resolution
  provisioner "shell" {
    inline = [
      "rm -f /etc/resolv.conf",
      "echo 'nameserver 8.8.8.8' > /etc/resolv.conf",
      "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
    ]
  }

  # Enable SSH (already enabled in Ubuntu by default)
  provisioner "shell" {
    inline = [
      "systemctl enable ssh"
    ]
  }

  # System Setup and Update
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "apt-get update",
      "apt-get upgrade -y",
      "apt-get install -y apt-transport-https ca-certificates curl gnupg vim git htop ntp"
    ]
  }

  # Configure kernel parameters for Kubernetes (Ubuntu uses different boot config)
  provisioner "shell" {
    inline = [
      "sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt || sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/cmdline.txt"
    ]
  }

  # Disable swap (required for Kubernetes)
  provisioner "shell" {
    inline = [
      "swapoff -a",
      "sed -i '/ swap / s/^/#/' /etc/fstab"
    ]
  }

  # Enable required kernel modules
  provisioner "shell" {
    inline = [
      "echo 'overlay' >> /etc/modules",
      "echo 'br_netfilter' >> /etc/modules"
    ]
  }

  # Set sysctl parameters for Kubernetes
  provisioner "shell" {
    inline = [
      "cat <<EOF > /etc/sysctl.d/k8s.conf",
      "net.bridge.bridge-nf-call-iptables  = 1",
      "net.bridge.bridge-nf-call-ip6tables = 1",
      "net.ipv4.ip_forward                 = 1",
      "EOF"
    ]
  }

  # Install containerd
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "apt-get update",
      "apt-get install -y containerd",
      "mkdir -p /etc/containerd",
      "containerd config default > /etc/containerd/config.toml",
      "sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "systemctl enable containerd"
    ]
  }

  # Install Kubernetes components
  provisioner "shell" {
    environment_vars = [
      "K8S_VERSION=${var.k8s_version}",
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/ /\" > /etc/apt/sources.list.d/kubernetes.list",
      "apt-get update",
      "apt-get install -y kubelet kubeadm kubectl",
      "apt-mark hold kubelet kubeadm kubectl",
      "systemctl enable kubelet"
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
    output     = "manifest.json"
    strip_path = true
  }
}
