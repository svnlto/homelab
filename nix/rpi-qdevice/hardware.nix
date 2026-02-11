_: {
  # The sd-image-aarch64.nix module (imported in flake.nix) handles all Raspberry Pi setup
  # Including kernel, bootloader, and firmware
  # This file is intentionally minimal to avoid conflicts

  # Enable GPU firmware (required for Raspberry Pi)
  hardware.enableRedistributableFirmware = true;
}
