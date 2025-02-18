#!/bin/bash

set -e

create_local_storage() {
  sudo mkdir -p /mnt/data/{grafana,loki,prometheus}
}

cgroup_memory_on() {
  sudo sed -i '/cgroup_enable=memory cgroup_memory=1/! s/$/ cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
}

arrch64_swap_off() {
  sudo dphys-swapfile swapoff
  sudo dphys-swapfile uninstall
  sudo systemctl disable dphys-swapfile
}

kernel_modules_load() {
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
  sudo modprobe overlay
  sudo modprobe br_netfilter
}

ipv4_forward_enable() {
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
  sudo sysctl --system
}

main() {
  local hostname=$(uname -n)
  local arch=$(uname -m)

  echo "Initializing - ${hostname} - ${arch}"

  if [[ ${arch} == "aarch64" ]]; then
    cgroup_memory_on
    arrch64_swap_off
  fi

  kernel_modules_load
  ipv4_forward_enable
  create_local_storage
}

main
