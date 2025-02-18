apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: willyhu.tw@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - dns01:
          route53:
            region: us-west-2
            accessKeyID: $ACME_ACCESS_KEY_ID
            secretAccessKeySecretRef:
              name: iam-acme
              key: secret-access-key
        selector:
          dnsZones:
            - "willyhu.tw"
            - "*.willyhu.tw"
