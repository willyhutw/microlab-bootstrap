#!/bin/bash

set -eo pipefail

main() {
  local hostname=$(uname -n)

  echo "Applying control-plane hardening flags - ${hostname}"

  local backup="/etc/kubernetes/manifests.bak-$(date +%Y%m%d-%H%M%S)"
  echo "### Backing up static pod manifests to ${backup} ###"
  sudo cp -r /etc/kubernetes/manifests "${backup}"

  sudo mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit

  if [[ -f /tmp/audit-policy.yaml ]]; then
    echo "### Installing audit policy to /etc/kubernetes/audit/policy.yaml ###"
    sudo cp /tmp/audit-policy.yaml /etc/kubernetes/audit/policy.yaml
  fi

  echo "### Regenerating control-plane static pod manifests ###"
  # kubeadm v1.36: the bare "control-plane" phase only accepts --rootfs/-v/--vmodule.
  # The "all" subcommand is required to pass --config and regenerate the manifests.
  # NOTE: this does not sync the kubeadm-config ConfigMap. A future "kubeadm upgrade
  # apply" regenerates the manifests from that ConfigMap and will overwrite these
  # flags, so re-run this task after an upgrade (or sync the ConfigMap beforehand).
  sudo kubeadm init phase control-plane all --config=/tmp/kubeadm-config.yml

  echo "### Tightening kubelet file permissions ###"
  sudo chmod 600 /var/lib/kubelet/config.yaml 2>/dev/null || true
  sudo chmod 600 /etc/systemd/system/kubelet.service.d/10-kubeadm.conf /lib/systemd/system/kubelet.service 2>/dev/null || true

  echo DONE
}

main
