#!/bin/bash

set -e

main() {
  local hostname=$(uname -n)
  local arch=$(uname -m)
  local K8S_VERSION="v1.32"

  echo "Installing kubeadm ${K8S_VERSION} - ${hostname} - ${arch}"

  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl gpg
  sudo mkdir -p -m 755 /etc/apt/keyrings
  if [ -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
    sudo rm /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  fi
  curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | sudo gpg --batch --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt update
  sudo apt install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
}

main
