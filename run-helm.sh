#!/usr/bin/env bash

set -ue

main() {
  helm repo add cilium https://helm.cilium.io --force-update
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server --force-update
  helm repo add jetstack https://charts.jetstack.io --force-update
  helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update
  helm repo add argo https://argoproj.github.io/argo-helm --force-update
  helm repo update

  # cilium
  helm upgrade --install -n kube-system cilium cilium/cilium --create-namespace -f ./helm-values/cilium.yml --version 1.17.1 --wait

  # metrics-server
  helm upgrade --install -n kube-system metrics-server metrics-server/metrics-server -f ./helm-values/metrics-server.yml --version 3.12.2 --wait

  # cert-manager
  helm upgrade --install -n cert-manager cert-manager jetstack/cert-manager --create-namespace --set installCRDs=true --version 1.16.3 --wait

  # letsencrypt cluster-issuer
  export CLOUDFLARE_ACME_SECRET=$(cat ~/cloudflare_acme_token.txt)
  kubectl -n cert-manager create secret generic cloudflare-api-token-secret --from-literal=api-token=$CLOUDFLARE_ACME_SECRET
  envsubst <./resources/letsencrypt-cluster-issuer.yml.tpl >./resources/letsencrypt-cluster-issuer.yml
  kubectl apply -f ./resources/letsencrypt-cluster-issuer.yml
  unset CLOUDFLARE_ACME_SECRET

  # istio
  helm upgrade --install -n istio-system istio-base istio/base --create-namespace --version 1.24.3 --wait
  helm upgrade --install -n istio-system istiod istio/istiod --create-namespace -f ./helm-values/istiod.yml --version 1.24.3 --wait
  helm upgrade --install -n istio-system istio-ingressgateway istio/gateway --create-namespace -f ./helm-values/istio-ingressgateway.yml --version 1.24.3 --wait

  # cilium-hubble
  helm upgrade --install -n kube-system cilium cilium/cilium --reuse-values -f ./helm-values/cilium-hubble.yml --version 1.17.1 --wait

  # argocd
  helm upgrade --install -n argocd argocd argo/argo-cd --create-namespace -f ./helm-values/argocd.yml --version 7.7.23 --wait

  # apply storage-class, pv, pvc and configmap for internal monitoring services.
  kubectl create namespace monitoring
  kubectl apply -f ./resources/local-storage.yml
  kubectl apply -f ./resources/monitoring/grafana
  kubectl apply -f ./resources/monitoring/loki
  kubectl apply -f ./resources/monitoring/prometheus
  kubectl apply -f ./resources/monitoring/prometheus-snmp-exporter
}

main
