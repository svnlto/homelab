{
  description = "Homelab Infrastructure Development Environment";

  nixConfig = {
    extra-substituters = "https://nixpkgs-terraform.cachix.org";
    extra-trusted-public-keys =
      "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
  };

  outputs = { nixpkgs, flake-utils, nixpkgs-terraform, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        terraform = nixpkgs-terraform.packages.${system}."terraform-1.14.1";
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            ansible
            ansible-lint
            pre-commit
            tflint
            vagrant
            qemu
            jq
            yq-go
            sshpass
            just
            terragrunt
            terraform
          ];

          shellHook = ''
            export QEMU_DIR="${pkgs.qemu}/share/qemu"
            export PATH="${pkgs.qemu}/bin:$PATH"

            echo "Homelab Development Environment"
            terraform version | head -1
            terragrunt --version | head -1
            ansible --version | head -1
          '';
        };
      });
}
