{
  description = "Raspberry Pi K8s Homelab Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Virtualization
            vagrant
            qemu

            # Provisioning
            ansible
            ansible-lint

            # Kubernetes tools
            kubectl
            kubernetes-helm
            k9s

            # Utilities
            jq
            yq-go
            sshpass
            just
          ];

          shellHook = ''
            # Set QEMU paths for vagrant-qemu plugin to use Nix QEMU
            export QEMU_DIR="${pkgs.qemu}/share/qemu"
            export PATH="${pkgs.qemu}/bin:$PATH"
          '';
        };
      });
}
