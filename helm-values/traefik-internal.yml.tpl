ingressClass:
  name: traefik-internal

service:
  type: LoadBalancer
  annotations:
    lbipam.cilium.io/ips: $TRAEFIK_INTERNAL_IP
  spec:
    externalTrafficPolicy: Cluster
