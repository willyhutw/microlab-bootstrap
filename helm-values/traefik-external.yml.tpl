ingressClass:
  name: traefik-external

service:
  type: LoadBalancer
  annotations:
    lbipam.cilium.io/ips: $TRAEFIK_EXTERNAL_IP
  spec:
    externalTrafficPolicy: Cluster
