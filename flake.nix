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
            python3Packages.molecule
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
            kubernetes-helm
            kubectl
            kubectx
            talosctl
            k9s
            argocd
            vcluster
            popeye
            helm-docs
            kubeconform
            # MCP server runtimes
            nodejs
            deno
            cargo
            go
          ];

          shellHook = ''
            export QEMU_DIR="${pkgs.qemu}/share/qemu"
            export PATH="${pkgs.qemu}/bin:$PATH"
            export K9S_CONFIG_DIR=~/.config/k9s

            # Kubernetes context
            KUBE_SHARED="$PWD/infrastructure/prod/compute/k8s-shared/configs/kubeconfig-shared"
            [ -f "$KUBE_SHARED" ] && export KUBECONFIG="$KUBE_SHARED"

            # Talos context
            TALOS_SHARED="$PWD/infrastructure/prod/compute/k8s-shared/configs/talosconfig-shared"
            [ -f "$TALOS_SHARED" ] && export TALOSCONFIG="$TALOS_SHARED"
          '';
        };
      });
}
