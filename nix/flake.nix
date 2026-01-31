{
  description = "NixOS configuration for Raspberry Pi Pi-hole";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-platforms = "aarch64-linux";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations = {
      rpi-pihole = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./rpi-pihole/configuration.nix
          {
            # Faster builds (disable compression)
            sdImage.compressImage = false;
          }
        ];
        specialArgs = {
          constants = import ./common/constants.nix;
        };
      };
    };
  };
}
