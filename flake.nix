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
    nixpkgs-packer.url =
      "github:NixOS/nixpkgs/dc205f7b4fdb04c8b7877b43edb7b73be7730081";
  };

  outputs =
    { self, nixpkgs, flake-utils, nixpkgs-terraform, nixpkgs-packer, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        pkgs-packer = import nixpkgs-packer {
          inherit system;
          config.allowUnfree = true;
        };

        terraform = nixpkgs-terraform.packages.${system}."terraform-1.14.1";
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs;
            [ ansible ansible-lint tflint vagrant qemu jq yq-go sshpass just ]
            ++ [ pkgs-packer.packer terraform ];

          shellHook = ''
            export QEMU_DIR="${pkgs.qemu}/share/qemu"
            export PATH="${pkgs.qemu}/bin:$PATH"

            echo "Homelab Development Environment"
            packer version | head -1
            terraform version | head -1
            ansible --version | head -1
          '';
        };
      });
}
