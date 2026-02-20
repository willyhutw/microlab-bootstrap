#!/bin/bash

set -eo pipefail

main() {
  local hostname=$(uname -n)
  local arch=$(uname -m)

  echo "Initializing K8S - ${hostname} - ${arch}"

  sudo kubeadm init --config=/tmp/kubeadm-config.yml --skip-phases=addon/kube-proxy
  mkdir -p $HOME/.kube
  sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  JOIN_CMD=$(sudo kubeadm token create --print-join-command)
  echo "$JOIN_CMD" | tee /tmp/kubeadm_join_cmd.txt
  chmod 600 /tmp/kubeadm_join_cmd.txt
}

main
