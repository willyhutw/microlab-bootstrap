#!/bin/bash

set -eo pipefail

cgroup_memory_on() {
  sudo sed -i '/cgroup_enable=memory cgroup_memory=1/! s/$/ cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
}

aarch64_swap_off() {
  # For Raspbian 13.2 trixie
  sudo systemctl stop dev-zram0.swap
  sudo systemctl disable dev-zram0.swap
  sudo systemctl mask dev-zram0.swapoff

  sudo systemctl stop systemd-zram-setup@zram0.service
  sudo systemctl disable systemd-zram-setup@zram0.service
  sudo systemctl mask systemd-zram-setup@zram0.service
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

  echo "Initializing system - ${hostname} - ${arch}"

  if [[ ${arch} == "aarch64" ]]; then
    cgroup_memory_on
    aarch64_swap_off
  fi

  kernel_modules_load
  ipv4_forward_enable
}

main
