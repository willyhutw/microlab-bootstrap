#!/bin/bash

set -eo pipefail

main() {
  local hostname=$(uname -n)
  local arch=$(uname -m)

  sudo apt-get update

  echo "Installing containerd - ${hostname} - ${arch}"

  sudo apt-get install -y containerd
  containerd config default | sudo tee /etc/containerd/config.toml
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  sudo systemctl restart containerd.service

  echo "Installing kubeadm ${KUBEADM_VERSION} - ${hostname} - ${arch}"

  sudo apt-get install -y apt-transport-https ca-certificates curl gpg
  sudo mkdir -p -m 755 /etc/apt/keyrings
  if [ -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
    sudo rm /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  fi
  curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBEADM_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBEADM_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
}

main
