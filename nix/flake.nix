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

  outputs = { nixpkgs, disko, ... }:
    let pkgs-x86 = nixpkgs.legacyPackages.x86_64-linux;
    in {
      packages.x86_64-linux.dumper-image =
        pkgs-x86.dockerTools.buildLayeredImage {
          name = "ghcr.io/svnlto/dumper";
          tag = "latest";
          contents = with pkgs-x86; [
            rsync
            openssh
            tailscale
            gnugrep
            findutils
            coreutils
            bash
            cacert
            curl
            jq
          ];
          config = {
            Cmd = [ "/bin/bash" "/app/rsync-photos.sh" ];
            Env = [
              "SSL_CERT_FILE=${pkgs-x86.cacert}/etc/ssl/certs/ca-bundle.crt"
            ];
          };
          extraCommands = ''
            mkdir -p app
            cp ${./dumper/rsync-photos-k8s.sh} app/rsync-photos.sh
          '';
        };

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
          specialArgs = { constants = import ./common/constants.nix; };
        };

        rpi-qdevice = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./rpi-qdevice/configuration.nix
            {
              # Faster builds (disable compression)
              sdImage.compressImage = false;
            }
          ];
          specialArgs = { constants = import ./common/constants.nix; };
        };

        arr-stack = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./arr-stack/disk-config.nix
            ./arr-stack/configuration.nix
          ];
          specialArgs = { constants = import ./common/constants.nix; };
        };

        jellyfin = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./jellyfin/disk-config.nix
            ./jellyfin/configuration.nix
          ];
          specialArgs = { constants = import ./common/constants.nix; };
        };

        dumper = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./dumper/disk-config.nix
            ./dumper/configuration.nix
          ];
          specialArgs = { constants = import ./common/constants.nix; };
        };
      };
    };
}
