# Microlab Bootstrap

Bootstrap script for setting up a multi-node Kubernetes cluster on Raspberry Pi using kubeadm, Cilium CNI, Traefik, cert-manager, and ArgoCD.

## Prerequisites

- Raspberry Pi nodes with Debian/Raspbian installed
- SSH access to all nodes from your local machine
- The following tools installed on your local machine:
  - `helm`
  - `kubectl`
  - `envsubst` (from `gettext`)
  - `direnv`

## Configuration

Edit `config.env` with your cluster settings and IP addresses:

```bash
export CLUSTER_NAME=micro
export KUBEADM_VERSION=v1.35
export K8S_VERSION=v1.35.4
export SANDBOX_IMAGE=registry.k8s.io/pause:3.10
export CILIUM_VERSION=1.19.3
export CERT_MANAGER_VERSION=1.20.2
export TRAEFIK_VERSION=39.0.9
export TRAEFIK_EXTERNAL_IP=192.168.12.91
export TRAEFIK_INTERNAL_IP=192.168.12.96
export ARGOCD_VERSION=9.5.13
```

Copy `.envrc.example` to `.envrc` and fill in your credentials:

```bash
cp .envrc.example .envrc
direnv allow
```

```bash
export ACME_EMAIL=your-email@example.com
export CF_ACME_TOKEN=your-cloudflare-api-token
export ARGOCD_DOMAIN=argocd.example.com
```

## Usage

```bash
./run.sh --task <task> --server <server1,server2,...> --ssh-user <username>
# addons task does not need --server or --ssh-user
./run.sh --task addons
```

## Tasks

Run tasks in order:

### 1. Base system setup (all nodes)

Enables cgroup memory (required on aarch64/Raspberry Pi), disables swap (including zram on Raspbian trixie), loads kernel modules (`overlay`, `br_netfilter`), enables IPv4 forwarding, and creates `/mnt/data/{grafana,prometheus,loki}` directories for persistent storage. Auto-reboots each node and waits for it to come back online.

```bash
./run.sh --task base --server 192.168.12.21,192.168.12.31,192.168.12.32 --ssh-user willyhu
```

### 2. Install kubeadm (all nodes)

Installs containerd (with systemd cgroup), kubeadm, kubelet, and kubectl. Versions are pinned and held via `apt-mark`.

```bash
./run.sh --task kubeadm --server 192.168.12.21,192.168.12.31,192.168.12.32 --ssh-user willyhu
```

### 3. Initialize cluster (control plane only)

Renders `kubeadm-config.yml` from the template and runs `kubeadm init` on the control plane node. Then:
- Copies kubeconfig to `~/.kube/<CLUSTER_NAME>` on your local machine
- Copies the join command to `~/.kube/<CLUSTER_NAME>-join-cmd` on your local machine
- Installs Cilium CNI via Helm

Only accepts a single server.

```bash
./run.sh --task init --server 192.168.12.21 --ssh-user willyhu
```

### 4. Join workers (worker nodes only)

Joins worker nodes to the cluster using the join command saved by step 3.

```bash
./run.sh --task join --server 192.168.12.31,192.168.12.32 --ssh-user willyhu
```

### 5. Install add-ons (local machine, no --server needed)

Installs all cluster add-ons using `~/.kube/<CLUSTER_NAME>` as the kubeconfig. Runs entirely from your local machine via Helm and kubectl:

- **cert-manager** — with Cloudflare API token secret and `letsencrypt-prod` ClusterIssuer (DNS-01)
- **Cilium IP pool** — `CiliumLoadBalancerIPPool` and `CiliumL2AnnouncementPolicy` for LB IP assignment
- **Traefik (internal)** — `traefik-internal` ingress class, fixed LoadBalancer IP from Cilium pool
- **Traefik (external)** — `traefik-external` ingress class, fixed LoadBalancer IP from Cilium pool
- **ArgoCD** — deployed via Helm, exposed via Traefik internal with a TLS ingress at `$ARGOCD_DOMAIN`

After completion, the ArgoCD initial admin password is printed to the console.

```bash
./run.sh --task addons
```

## Project Structure

```
microlab-bootstrap/
├── config.env                               # Cluster versions, IPs, and settings
├── .envrc.example                           # Credentials template (copy to .envrc)
├── run.sh                                   # Entry point; addons logic lives here
├── tasks/
│   ├── base.sh                              # System preparation
│   ├── kubeadm.sh                           # containerd + kubeadm install
│   ├── init.sh                              # kubeadm init
│   └── join.sh                              # Placeholder (join logic is in run.sh)
├── resources/
│   ├── kubeadm-config.yml.tpl              # kubeadm config template
│   ├── letsencrypt-cluster-issuer.yml.tpl  # Let's Encrypt ClusterIssuer template
│   ├── argocd-ingress.yml.tpl              # ArgoCD Ingress template
│   └── cilium-ippool.yml                   # Cilium IP pools and L2 announcement policy
└── helm-values/
    ├── cilium.yml.tpl                       # Cilium values template
    ├── cert-manager.yml                     # cert-manager values
    ├── traefik-internal.yml.tpl            # Traefik internal values template
    ├── traefik-external.yml.tpl            # Traefik external values template
    └── argocd.yml                          # ArgoCD values
```
