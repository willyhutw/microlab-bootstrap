---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $CONTROL_PLANE_ENDPOINT
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock

---
apiVersion: kubeadm.k8s.io/v1beta4
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
apiServer:
  extraArgs:
    - name: profiling
      value: "false"
    - name: audit-log-path
      value: /var/log/kubernetes/audit/audit.log
    - name: audit-log-maxage
      value: "30"
    - name: audit-log-maxbackup
      value: "10"
    - name: audit-log-maxsize
      value: "100"
    - name: audit-policy-file
      value: /etc/kubernetes/audit/policy.yaml
  extraVolumes:
    - name: audit-policy
      hostPath: /etc/kubernetes/audit
      mountPath: /etc/kubernetes/audit
      readOnly: true
      pathType: DirectoryOrCreate
    - name: audit-log
      hostPath: /var/log/kubernetes/audit
      mountPath: /var/log/kubernetes/audit
      pathType: DirectoryOrCreate
controllerManager:
  extraArgs:
    - name: profiling
      value: "false"
scheduler:
  extraArgs:
    - name: profiling
      value: "false"
