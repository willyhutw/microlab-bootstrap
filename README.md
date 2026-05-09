# Microlab Bootstrap

Bootstrap script for setting up a multi-node Kubernetes cluster on Raspberry Pi using kubeadm, Cilium CNI, and cert-manager. After bootstrap, the cluster is registered to an external ArgoCD instance which manages all subsequent workloads (Istio, monitoring, etc.).

## Prerequisites

- Raspberry Pi nodes with Debian/Raspbian installed
- SSH access to all nodes from your local machine
- The following tools installed on your local machine:
  - `helm`
  - `kubectl`
  - `argocd` CLI
  - `envsubst` (from `gettext`)
  - `direnv`

## Configuration

Edit `config.env` with your cluster settings:

```bash
export CLUSTER_NAME=micro
export KUBEADM_VERSION=v1.35
export K8S_VERSION=v1.35.4
export SANDBOX_IMAGE=registry.k8s.io/pause:3.10
export CILIUM_VERSION=1.19.3
export CERT_MANAGER_VERSION=1.20.2
```

Copy `.envrc.example` to `.envrc` and fill in your credentials:

```bash
cp .envrc.example .envrc
direnv allow
```

```bash
export ACME_EMAIL=your-email@example.com
export CF_ACME_TOKEN=your-cloudflare-api-token
export ARGOCD_SERVER=argocd.willyhu.tw
export ARGOCD_USERNAME=admin
export ARGOCD_PASSWORD=your-argocd-password
export ARGOCD_KUBECONFIG=$HOME/.kube/argocd
```

## Usage

```bash
./run.sh --task <task> --server <server1,server2,...> --ssh-user <username>
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

Renders `kubeadm-config.yml` from the template and runs `kubeadm init` on the control plane node. Then runs the following entirely from the local machine:

- Copies kubeconfig to `~/.kube/<CLUSTER_NAME>` and join command to `~/.kube/<CLUSTER_NAME>-join-cmd`
- Installs Cilium CNI via Helm
- Applies Cilium `CiliumLoadBalancerIPPool` and `CiliumL2AnnouncementPolicy`
- Installs cert-manager via Helm, creates the Cloudflare API token secret, and applies the `letsencrypt-prod` ClusterIssuer
- Registers the cluster to the external ArgoCD instance

Only accepts a single server.

```bash
./run.sh --task init --server 192.168.12.21 --ssh-user willyhu
```

### 4. Join workers (worker nodes only)

Joins worker nodes to the cluster using the join command saved by step 3.

```bash
./run.sh --task join --server 192.168.12.31,192.168.12.32 --ssh-user willyhu
```

### 5. Apply ArgoCD applications (local machine)

After workers have joined, apply the ArgoCD `Application` manifests so ArgoCD begins deploying all workloads (Istio, monitoring stack, etc.) automatically.

```bash
# from the microlab repo
.ci/create.sh argocd/internal/apps
```

## Project Structure

```
microlab-bootstrap/
├── config.env                               # Cluster versions and settings
├── .envrc.example                           # Credentials template (copy to .envrc)
├── run.sh                                   # Entry point
├── tasks/
│   ├── base.sh                              # System preparation
│   ├── kubeadm.sh                           # containerd + kubeadm install
│   ├── init.sh                              # kubeadm init
│   └── join.sh                              # Placeholder (join logic is in run.sh)
├── resources/
│   ├── kubeadm-config.yml.tpl              # kubeadm config template
│   ├── letsencrypt-cluster-issuer.yml.tpl  # Let's Encrypt ClusterIssuer template
│   └── cilium-ippool.yml                   # Cilium IP pools and L2 announcement policy
└── helm-values/
    ├── cilium.yml.tpl                       # Cilium values template
    └── cert-manager.yml                     # cert-manager values
```
