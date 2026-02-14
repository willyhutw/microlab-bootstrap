kubeProxyReplacement: true
l2announcements:
  enabled: true
externalIPs:
  enabled: true
k8sServiceHost: $CONTROL_PLANE_ENDPOINT
k8sServicePort: 6443
socketLB:
  hostNamespaceOnly: true
cni:
  exclusive: false
