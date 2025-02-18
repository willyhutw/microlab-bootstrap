#!/bin/bash

set -e

main() {
  local hostname=$(uname -n)
  local arch=$(uname -m)

  echo "Installing containerd - ${hostname} - ${arch}"

  sudo apt-get update
  sudo apt-get install -y containerd
  containerd config default | sudo tee /etc/containerd/config.toml
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  sudo systemctl restart containerd.service
}

main
