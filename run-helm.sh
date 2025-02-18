#!/usr/bin/env bash

set -ue

main() {
  helm repo add cilium https://helm.cilium.io --force-update
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server --force-update
  helm repo add jetstack https://charts.jetstack.io --force-update
  helm repo add metallb https://metallb.github.io/metallb --force-update
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
  helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update
  helm repo add argo https://argoproj.github.io/argo-helm --force-update
  helm repo update

  # cilium-base
  helm upgrade --install -n kube-system cilium cilium/cilium --create-namespace --version 1.16.6 --wait

  # metrics-server
  helm upgrade --install -n kube-system metrics-server metrics-server/metrics-server -f ./helm-values/metrics-server.yml --version 3.12.2 --wait

  # cert-manager
  helm upgrade --install -n cert-manager cert-manager jetstack/cert-manager --create-namespace --set installCRDs=true --version 1.16.3 --wait

  # letsencrypt cluster-issuer
  IFS=',' read -r VAR1 VAR2 <~/acme_access_keys.csv && export ACME_ACCESS_KEY_ID=$(echo "$VAR1" | xargs) ACME_SECRET_ACCESS_KEY=$(echo "$VAR2" | xargs)
  kubectl -n cert-manager create secret generic iam-acme --from-literal=secret-access-key=$ACME_SECRET_ACCESS_KEY
  envsubst <./resources/letsencrypt-cluster-issuer.yml.tpl >./resources/letsencrypt-cluster-issuer.yml
  kubectl apply -f ./resources/letsencrypt-cluster-issuer.yml
  unset ACME_ACCESS_KEY_ID ACME_SECRET_ACCESS_KEY

  # metallb
  helm upgrade --install -n metallb-system metallb metallb/metallb --create-namespace --version 0.14.9 --wait
  kubectl apply -f ./resources/metallb-config.yml

  # ingress-nginx
  helm upgrade --install -n ingress-nginx ingress-nginx ingress-nginx/ingress-nginx --create-namespace -f ./helm-values/ingress-nginx-values.yml --version 4.12.0 --wait

  # cilium-hubble
  helm upgrade --install -n kube-system cilium cilium/cilium --reuse-values -f ./helm-values/cilium-hubble.yml --version 1.16.6 --wait

  # argocd
  helm upgrade --install -n argocd argocd argo/argo-cd --create-namespace -f ./helm-values/argocd.yml --version 7.7.23 --wait

  # apply storage-class, pv, pvc and configmap for internal monitoring services.
  kubectl create namespace monitoring
  kubectl apply -f ./resources/local-storage.yml
  kubectl apply -f ./resources/monitoring/grafana
  kubectl apply -f ./resources/monitoring/loki
  kubectl apply -f ./resources/monitoring/prometheus
  kubectl apply -f ./resources/monitoring/prometheus-snmp-exporter

  # add namespace labels
  kubectl label namespaces kube-system internal=yes --overwrite=true
  kubectl label namespaces argocd internal=yes --overwrite=true
  kubectl label namespaces monitoring internal=yes --overwrite=true
}

main
