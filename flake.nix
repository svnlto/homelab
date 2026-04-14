{
  description = "Homelab Infrastructure Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            ansible
            ansible-lint
            python3Packages.molecule
            pre-commit
            tflint
            jq
            just
            terragrunt
            opentofu
            kubernetes-helm
            kubectl
            talosctl
            k9s
            argocd
            vcluster
            helm-docs
            kubeconform
            # MCP server runtimes
            nodejs
            deno
          ];

          shellHook = ''
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
