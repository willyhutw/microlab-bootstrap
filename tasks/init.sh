#!/bin/bash

set -eo pipefail

main() {
  local hostname=$(uname -n)
  local arch=$(uname -m)

  echo "Initializing K8S - ${hostname} - ${arch}"

  # The apiserver static pod references /etc/kubernetes/audit/policy.yaml and
  # logs to /var/log/kubernetes/audit (see kubeadm-config.yml.tpl). Both must
  # exist before `kubeadm init` or the apiserver crash-loops on a missing
  # audit-policy-file. Keep this in sync with tasks/control-plane-flags.sh.
  echo "### Installing audit policy and creating audit dirs ###"
  sudo mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
  sudo install -m 600 -o root -g root /tmp/audit-policy.yaml /etc/kubernetes/audit/policy.yaml

  sudo kubeadm init --config=/tmp/kubeadm-config.yml --skip-phases=addon/kube-proxy
  mkdir -p $HOME/.kube
  sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  JOIN_CMD=$(sudo kubeadm token create --print-join-command)
  echo "$JOIN_CMD" | tee /tmp/kubeadm_join_cmd.txt
  chmod 600 /tmp/kubeadm_join_cmd.txt
}

main
