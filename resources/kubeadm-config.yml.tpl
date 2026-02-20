---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $CONTROL_PLANE_ENDPOINT
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/containerd/containerd.sock

---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: $K8S_VERSION
controlPlaneEndpoint: $CONTROL_PLANE_ENDPOINT:6443
networking:
  serviceSubnet: 10.96.0.0/16
  podSubnet: 10.244.0.0/16
  dnsDomain: cluster.local
certificatesDir: /etc/kubernetes/pki
imageRepository: registry.k8s.io
clusterName: $CLUSTER_NAME
