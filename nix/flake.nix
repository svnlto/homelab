{
  description = "NixOS configurations for homelab infrastructure";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-platforms = "aarch64-linux x86_64-linux";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }: {
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

      arr-stack = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./arr-stack/disk-config.nix
          ./arr-stack/configuration.nix
        ];
        specialArgs = {
          constants = import ./common/constants.nix;
        };
      };
    };
  };
}
