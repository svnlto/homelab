{
  description = "NixOS configurations for homelab infrastructure";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-platforms = "aarch64-linux x86_64-linux";
  };

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { nixpkgs, ... }:
    let pkgs-x86 = nixpkgs.legacyPackages.x86_64-linux;
    in {
      packages.x86_64-linux.osxphotos-export-image = let
        osxphotos-linux =
          pkgs-x86.python312Packages.osxphotos.overridePythonAttrs (old: {
            dependencies =
              builtins.filter (dep: (dep.pname or "") != "utitools")
              (old.dependencies or [ ]);
            postPatch = (old.postPatch or "") + ''
              # Strip macOS-only markers that reference platform_release —
              # packaging>=22.0 chokes on non-PEP 440 kernel versions
              # (e.g. "6.11.0-1018-azure", "6.18.5-talos")
              sed -i '/platform_release/d' pyproject.toml setup.cfg setup.py 2>/dev/null || true
              # Also strip utitools (macOS-only)
              sed -i '/utitools/d' pyproject.toml setup.cfg setup.py 2>/dev/null || true
              # Relax whenever version pin — nixpkgs has 0.9.5, osxphotos pins <0.9.0
              sed -i 's/whenever>=0.8.3,<0.9.0/whenever>=0.8.3/' pyproject.toml setup.cfg setup.py 2>/dev/null || true
            '';
          });
      in pkgs-x86.dockerTools.buildLayeredImage {
        name = "ghcr.io/svnlto/osxphotos-export";
        tag = "latest";
        contents = with pkgs-x86; [
          osxphotos-linux
          gnugrep
          coreutils
          bash
          curl
          jq
        ];
        config = { Cmd = [ "/bin/bash" "/app/export-photos.sh" ]; };
        extraCommands = ''
          mkdir -p app etc
          mkdir -p -m 1777 tmp
          cp ${./osxphotos-export/export-photos.sh} app/export-photos.sh
          echo "export:x:1003:1000:export:/tmp:/bin/bash" >> etc/passwd
          echo "export:x:1000:" >> etc/group
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

      };
    };
}
