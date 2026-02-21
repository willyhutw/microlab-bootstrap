#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

usage() {
  echo "Usage: $0 --task <base|kubeadm|init|join> --server <server1,server2,server3> --ssh-user <username>"
  echo "Example: $0 --task base --server 192.168.12.21,192.168.12.31,192.168.12.32 --ssh-user willyhu"
  echo "Example: $0 --task kubeadm --server 192.168.12.21,192.168.12.31,192.168.12.32 --ssh-user willyhu"
  echo "Example: $0 --task init --server 192.168.12.21 --ssh-user willyhu"
  echo "Example: $0 --task join --server 192.168.12.31,192.168.12.32 --ssh-user willyhu"
  exit 1
}

if [[ $# -lt 6 ]]; then
  usage
fi

TASK=""
SERVERS=""
SSH_USER=""

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
  --ssh-user)
    SSH_USER="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1"
    usage
    ;;
  esac
done

[[ -z "$TASK" || -z "$SERVERS" || -z "$SSH_USER" ]] && usage

if [[ ! -f "${SCRIPT_DIR}/tasks/${TASK}.sh" ]]; then
  echo "!!! Task script '${SCRIPT_DIR}/tasks/${TASK}.sh' not found !!!"
  exit 1
fi

if [[ ${TASK,,} == "init" && "$SERVERS" == *","* ]]; then
  echo "!!! Task 'init' only supports a single server !!!"
  exit 1
fi

IFS=',' read -ra SERVER_LIST <<<"$SERVERS"

for SERVER in "${SERVER_LIST[@]}"; do
  echo "### Running task '${TASK}' on server '${SERVER}' ###"

  if [[ ${TASK,,} == "kubeadm" ]]; then
    ssh "$SSH_USER@${SERVER}" "KUBEADM_VERSION=${KUBEADM_VERSION} bash -s" <"${SCRIPT_DIR}/tasks/kubeadm.sh"
  elif [[ ${TASK,,} == "init" ]]; then
    echo "### Rendering 'kubeadm-config.yml.tpl' ###"
    export CONTROL_PLANE_ENDPOINT=${SERVER}
    envsubst '$CLUSTER_NAME $K8S_VERSION $CONTROL_PLANE_ENDPOINT' <"${SCRIPT_DIR}/resources/kubeadm-config.yml.tpl" >"${SCRIPT_DIR}/resources/kubeadm-config.yml"

    echo "### Copying resource 'kubeadm-config.yml' to server '${SERVER}' ###"
    scp "${SCRIPT_DIR}/resources/kubeadm-config.yml" "$SSH_USER@$SERVER:/tmp/"
    ssh "$SSH_USER@${SERVER}" "bash -s" <"${SCRIPT_DIR}/tasks/${TASK}.sh"

    echo "### Copying join command from server '${SERVER}' ###"
    mkdir -p "$HOME/.kube"
    scp "$SSH_USER@${SERVER}:/tmp/kubeadm_join_cmd.txt" "$HOME/.kube/${CLUSTER_NAME}-join-cmd"
    chmod 600 "$HOME/.kube/${CLUSTER_NAME}-join-cmd"

    echo "### Copying kubeconfig to '$HOME/.kube/${CLUSTER_NAME}' ###"
    scp "$SSH_USER@${SERVER}:~/.kube/config" "$HOME/.kube/${CLUSTER_NAME}"
    chmod 600 "$HOME/.kube/${CLUSTER_NAME}"
    export KUBECONFIG="$HOME/.kube/${CLUSTER_NAME}"

    echo "### Installing CNI (Cilium) ###"
    envsubst '$CONTROL_PLANE_ENDPOINT' <"${SCRIPT_DIR}/helm-values/cilium.yml.tpl" >"${SCRIPT_DIR}/helm-values/cilium.yml"
    helm repo add cilium https://helm.cilium.io --force-update
    helm repo update cilium
    helm upgrade --install -n kube-system cilium cilium/cilium --create-namespace -f "${SCRIPT_DIR}/helm-values/cilium.yml" --version ${CILIUM_VERSION} --wait

    echo "### Installing cert-manager ###"
    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update jetstack
    helm upgrade --install -n cert-manager cert-manager jetstack/cert-manager --create-namespace --set crds.enabled=true --version ${CERT_MANAGER_VERSION} --wait
    CLOUDFLARE_API_TOKEN=$(cat ~/cloudflare_acme_token.txt)
    kubectl -n cert-manager create secret generic cloudflare-api-token-secret \
      --from-literal=api-token=${CLOUDFLARE_API_TOKEN} \
      --dry-run=client -o yaml | kubectl apply -f -
    unset CLOUDFLARE_API_TOKEN
    envsubst '$ACME_EMAIL' <"${SCRIPT_DIR}/resources/letsencrypt-cluster-issuer.yml.tpl" | kubectl apply -f -

    echo "### Registering cluster '${CLUSTER_NAME}' to ArgoCD ###"
    argocd login ${ARGOCD_SERVER} --username ${ARGOCD_USERNAME} --password ${ARGOCD_PASSWORD} --grpc-web
    if argocd cluster get "https://${SERVER}:6443" --grpc-web &>/dev/null; then
      echo "### Cluster '${CLUSTER_NAME}' already registered in ArgoCD, skipping ###"
    else
      KUBECONFIG=${ARGOCD_KUBECONFIG}:$HOME/.kube/${CLUSTER_NAME} argocd cluster add kubernetes-admin@${CLUSTER_NAME} --name ${CLUSTER_NAME} --grpc-web
    fi

    unset CONTROL_PLANE_ENDPOINT KUBECONFIG
  elif [[ ${TASK,,} == "join" ]]; then
    ssh "$SSH_USER@${SERVER}" "sudo bash -s" <"$HOME/.kube/${CLUSTER_NAME}-join-cmd"
  else
    ssh "$SSH_USER@${SERVER}" "bash -s" <"${SCRIPT_DIR}/tasks/${TASK}.sh"
  fi

  if [[ ${TASK,,} == "base" ]]; then
    echo "### Rebooting server '${SERVER}' ###"
    ssh "$SSH_USER@${SERVER}" "sudo reboot" || true
    echo "### Waiting for server '${SERVER}' to come back online ###"
    sleep 10
    until ssh -o ConnectTimeout=5 "$SSH_USER@${SERVER}" "true" 2>/dev/null; do
      sleep 5
    done
  fi

  echo "### Task '${TASK}' successfully executed on '${SERVER}' ###"
done
