default:
    @just --list

# Validate Packer template
packer-validate:
    cd packer && packer validate rpi-k8s-base.pkr.hcl

# Start Vagrant VM
vagrant-up:
    vagrant up

# Stop Vagrant VM
vagrant-down:
    vagrant halt

# Destroy Vagrant VM
vagrant-destroy:
    vagrant destroy -f

# SSH into Vagrant VM
vagrant-ssh:
    vagrant ssh

# Build Packer image (30-60 min)
packer-build:
    @if ! vagrant status | grep -q "running"; then vagrant up; fi
    vagrant rsync
    vagrant ssh -c "cd /home/vagrant/packer && sudo rm -rf .packer_cache && mkdir -p output-rpi-k8s && sudo docker run --rm --privileged -v /dev:/dev -v \$(pwd):/build mkaczanowski/packer-builder-arm:latest build /build/rpi-k8s-base.pkr.hcl"
    @mkdir -p packer/output-rpi-k8s
    vagrant ssh -c "sudo chmod 644 /home/vagrant/packer/output-rpi-k8s/*"
    @echo "📦 Copying image to host (this may take 2-5 minutes for 8GB)..."
    vagrant ssh-config > /tmp/vagrant-ssh-config
    rsync -avh --progress -e "ssh -F /tmp/vagrant-ssh-config" default:/home/vagrant/packer/output-rpi-k8s/ packer/output-rpi-k8s/
    @rm -f /tmp/vagrant-ssh-config
    @echo "✅ Image: packer/output-rpi-k8s/rpi-k8s-base.img"

# Test Ansible connectivity
test-ansible:
    cd ansible && ansible all -m ping

# Check Ansible syntax
test-syntax:
    cd ansible && ansible-playbook -i inventory.yml site.yml --syntax-check

# Ansible dry-run
ansible-check:
    cd ansible && ansible-playbook -i inventory.yml site.yml --check

# Deploy cluster
ansible-deploy:
    cd ansible && ansible-playbook -i inventory.yml site.yml

# Install MetalLB
k8s-install-metallb:
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
    kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
    kubectl apply -f kubernetes/manifests/metallb-config.yaml

# Install Longhorn
k8s-install-longhorn:
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
    helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.7.2 -f kubernetes/manifests/longhorn-values.yaml

# Install cert-manager
k8s-install-certmanager:
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.16.2 --set crds.enabled=true
    kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/instance=cert-manager --timeout=90s
    kubectl apply -f kubernetes/manifests/cert-manager.yaml

# Install Traefik
k8s-install-traefik:
    helm repo add traefik https://traefik.github.io/charts
    helm repo update
    helm install traefik traefik/traefik -n traefik --create-namespace -f kubernetes/manifests/traefik-values.yaml

# Install all components
k8s-install-all:
    @just k8s-install-metallb
    @just k8s-install-longhorn
    @just k8s-install-certmanager
    @just k8s-install-traefik

# Show cluster status
k8s-status:
    @echo "=== Nodes ==="
    kubectl get nodes -o wide
    @echo ""
    @echo "=== Pods ==="
    kubectl get pods -A
    @echo ""
    @echo "=== Services ==="
    kubectl get svc -A

# Get kubeconfig
k8s-get-config NODE="192.168.1.101":
    scp ubuntu@{{NODE}}:~/.kube/config ~/.kube/homelab-config
    @echo "✓ Saved to ~/.kube/homelab-config"
    @echo "  export KUBECONFIG=~/.kube/homelab-config"

# Launch k9s
k9s:
    k9s

# Clean build artifacts
clean:
    rm -rf packer/output-* packer/packer_cache packer/*.img ansible/*.retry

# Update Helm repos
helm-update:
    helm repo update

# List Helm releases
helm-list:
    helm list -A

# Test nginx deployment
test-deploy:
    kubectl create deployment nginx-test --image=nginx:alpine --replicas=2 || true
    kubectl expose deployment nginx-test --port=80 --type=LoadBalancer || true
    @echo "Get IP: kubectl get svc nginx-test"

# Delete test deployment
test-cleanup:
    kubectl delete deployment nginx-test || true
    kubectl delete service nginx-test || true

# SSH to node
ssh NODE:
    ssh ubuntu@{{NODE}}

# Backup etcd
backup-etcd:
    kubectl -n kube-system exec etcd-rpi-control-01 -- sh -c "ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key snapshot save /tmp/etcd-backup.db"
    kubectl cp kube-system/etcd-rpi-control-01:/tmp/etcd-backup.db ./etcd-backup-$(date +%Y%m%d-%H%M%S).db

# Full deployment
deploy-full:
    @just test-ansible
    @just ansible-deploy
    @just k8s-install-all
    @just k8s-status

# Rebuild image
rebuild:
    @just packer-build
