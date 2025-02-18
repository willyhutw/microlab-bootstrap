#!/bin/bash

set -e

usage() {
  echo "Usage: $0 --task <base|containerd|kubeadm|init|join> --server <server1,server2,server3> [--cluster-name dev] [--k8s-version v1.32.1]"
  echo "Example: $0 --task init --server 192.168.13.21,192.168.13.31"
  exit 1
}

if [[ $# -lt 4 ]]; then
  usage
fi

TASK=""
SERVERS=""
USER="willyhu"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --task)
    TASK="$2"
    shift 2
    ;;
  --server)
    SERVERS="$2"
    shift 2
    ;;
  --cluster-name)
    CLUSTER_NAME="$2"
    shift 2
    ;;
  --k8s-version)
    K8S_VERSION="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1"
    usage
    ;;
  esac
done

if [[ ! -f "./tasks/${TASK}.sh" ]]; then
  echo "!!! Task script './tasks/${TASK}.sh' not found !!!"
  exit 1
fi

IFS=',' read -ra SERVER_LIST <<<"$SERVERS"

for SERVER in "${SERVER_LIST[@]}"; do
  echo "### Running task '${TASK}' on server '${SERVER}' ###"

  if [[ ${TASK,,} == "init" ]]; then
    echo "### Rendering 'kubeadm-config.yml.tpl' ###"
    export CLUSTER_NAME=${CLUSTER_NAME:-"dev"}
    export K8S_VERSION=${K8S_VERSION:-"v1.32.1"}
    export CONTROL_PLANE_ENDPOINT=${SERVER}
    envsubst <./resources/kubeadm-config.yml.tpl >./resources/kubeadm-config.yml
    unset CLUSTER_NAME K8S_VERSION CONTROL_PLANE_ENDPOINT

    echo "### Copying resource 'kubeadm-config.yml' to server '${SERVER}' ###"
    scp "./resources/kubeadm-config.yml" $USER@$SERVER:/tmp/
    ssh "$USER@${SERVER}" "bash -s" <"./tasks/${TASK}.sh"

    echo "### Copying 'kubeadm_join_cmd.txt' to host ###"
    scp $USER@${SERVER}:/tmp/kubeadm_join_cmd.txt /tmp/
  elif [[ ${TASK,,} == "join" ]]; then
    ssh "$USER@${SERVER}" "sudo bash -s" <"/tmp/kubeadm_join_cmd.txt"
  else
    ssh "$USER@${SERVER}" "bash -s" <"./tasks/${TASK}.sh"
  fi

  echo "### Task '${TASK}' successfully executed on '${SERVER}' ###"
done
