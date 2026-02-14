# Microlab Bootstrap

Bootstrap script for setting up a multi-node Kubernetes cluster on Raspberry Pi using kubeadm and Cilium CNI.

## Prerequisites

- Raspberry Pi nodes with Debian/Raspbian installed
- SSH access to all nodes
- Helm installed on the local machine

## Configuration

Edit `config.env` with your settings:

```bash
export CLUSTER_NAME=micro
export KUBEADM_VERSION=v1.35
export K8S_VERSION=v1.35.1
export CILIUM_VERSION=1.18.7
```

## Usage

```bash
./run.sh --task <task> --server <server1,server2,...> --ssh-user <username>
```

## Tasks

Run tasks in order:

### 1. Base system setup (all nodes)

Configures kernel modules, sysctl, swap off. Auto-reboots each node and waits for it to come back.

```bash
./run.sh --task base --server 192.168.12.21,192.168.12.31,192.168.12.32 --ssh-user willyhu
```

### 2. Install kubeadm (all nodes)

Installs containerd, kubeadm, kubelet, and kubectl.

```bash
./run.sh --task kubeadm --server 192.168.12.21,192.168.12.31,192.168.12.32 --ssh-user willyhu
```

### 3. Initialize cluster (control plane only)

Runs `kubeadm init`, copies kubeconfig to local machine, and installs Cilium CNI.

```bash
./run.sh --task init --server 192.168.12.21 --ssh-user willyhu
```

### 4. Join workers (worker nodes only)

Joins worker nodes to the cluster using the join command from step 3.

```bash
./run.sh --task join --server 192.168.12.31,192.168.12.32 --ssh-user willyhu
```

## Project Structure

```
microlab-bootstrap/
├── config.env                      # Versions and defaults
├── run.sh                          # Entry point
├── tasks/
│   ├── base.sh                     # System preparation
│   ├── kubeadm.sh                  # containerd + kubeadm install
│   ├── init.sh                     # kubeadm init
│   └── join.sh                     # Placeholder (logic in run.sh)
├── resources/
│   └── kubeadm-config.yml.tpl      # kubeadm config template
└── helm-values/
    └── cilium.yml.tpl              # Cilium values template
```
