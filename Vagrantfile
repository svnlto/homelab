# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "cloud-image/ubuntu-24.04"
  config.vm.boot_timeout = 600
  config.vm.hostname = "homelab-packer"

  config.ssh.insert_key = true

  # Use rsync for file sharing with QEMU
  config.vm.synced_folder "./packer", "/home/vagrant/packer",
    type: "rsync",
    rsync__auto: true,
    rsync__exclude: ['.git/', '.packer_cache/', 'output-rpi-k8s/']

  config.vm.provider "qemu" do |qemu|
    qemu.name = "homelab-packer"
    qemu.memory = "4096"
    qemu.arch = "aarch64"
    qemu.machine = "virt,accel=hvf"
    qemu.cpu = "host"
    qemu.net_device = "virtio-net-pci"
    qemu.cpus = 6
    qemu.extra_qemu_args = %w(-display none -smp 6,cores=6,threads=1,sockets=1)
    qemu.disk_resize = "50G"

    # Use QEMU from Nix environment
    if ENV['QEMU_DIR']
      qemu.qemu_dir = ENV['QEMU_DIR']
    end
  end

  config.vm.provision "shell", inline: <<-SHELL
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
      apt-get update
      apt-get install -y docker.io
    fi

    # Build the image
    cd /home/vagrant/packer
    sudo rm -rf .packer_cache output-rpi-k8s
    mkdir -p output-rpi-k8s
    sudo docker run --rm --privileged \
      -v /dev:/dev \
      -v $(pwd):/build \
      mkaczanowski/packer-builder-arm:latest \
      build /build/rpi-k8s-base.pkr.hcl
  SHELL
end
