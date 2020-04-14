# Cert Manager

## Add policy to TKG Cluster
```
kubectl create clusterrolebinding privileged-cluster-role-binding \
    --clusterrole=vmware-system-tmc-psp-privileged \
    --group=system:authenticated
```

## Install Cert Manager

1. Install the CRDs resources separately:

```
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.10/deploy/manifests/00-crds.yaml
sleep 5
```

2. Create the namespace for cert-manager and label it to disable resource validation:

```
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
```

3. Install the cert-manager Helm chart:

```
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager --namespace cert-manager --wait jetstack/cert-manager --version v0.10.1
```

Output:

```
NAME: cert-manager
LAST DEPLOYED: Sun Apr 12 12:06:41 2020
NAMESPACE: cert-manager
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
cert-manager has been deployed successfully!

In order to begin issuing certificates, you will need to set up a ClusterIssuer
or Issuer resource (for example, by creating a 'letsencrypt-staging' issuer).

More information on the different types of issuers and how to configure them
can be found in our documentation:

https://docs.cert-manager.io/en/latest/reference/issuers.html

For information on how to configure cert-manager to automatically provision
Certificates for Ingress resources, take a look at the `ingress-shim`
documentation:

https://docs.cert-manager.io/en/latest/reference/ingress-shim.html
```

## Create ClusterIssuer for Let's Encrypt

Create ClusterIssuer for Route53 used by cert-manager. It will allow Let's Encrypt to generate certificate. Route53 (DNS) method of requesting certificate from Let's Encrypt must be used to create wildcard certificate *.mydomain.com.

```
export USER_AWS_SECRET_ACCESS_KEY_BASE64=$(echo -n "$USER_AWS_SECRET_ACCESS_KEY" | base64)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aws-user-secret-access-key-secret
  namespace: cert-manager
data:
  secret-access-key: $USER_AWS_SECRET_ACCESS_KEY_BASE64
---
```


```
cat << EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging-dns
  namespace: cert-manager
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: gborges@vmware.com
    privateKeySecretRef:
      name: letsencrypt-staging-dns
    dns01:
      providers:
      - name: aws-route53
        route53:
          accessKeyID: ${USER_AWS_ACCESS_KEY_ID}
          region: us-east-1
          secretAccessKeySecretRef:
            name: aws-user-secret-access-key-secret
            key: secret-access-key
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production-dns
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: gborges@vmware.com
    privateKeySecretRef:
      name: letsencrypt-production-dns
    dns01:
      providers:
      - name: aws-route53
        route53:
          accessKeyID: ${USER_AWS_ACCESS_KEY_ID}
          region: us-east-1
          secretAccessKeySecretRef:
            name: aws-user-secret-access-key-secret
            key: secret-access-key
EOF

```

## Generate TLS certificate

```
cat << EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: ingress-cert-${LETSENCRYPT_ENVIRONMENT}
  namespace: cert-manager
spec:
  secretName: ingress-cert-${LETSENCRYPT_ENVIRONMENT}
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-${LETSENCRYPT_ENVIRONMENT}-dns
  commonName: "*.${MY_DOMAIN}"
  dnsNames:
  - "*.${MY_DOMAIN}"
  acme:
    config:
    - dns01:
        provider: aws-route53
      domains:
      - "*.${MY_DOMAIN}"
EOF
```


## Verify Certificate 

Before moving on make sure that your certificate is issued successfully:

```
kubectl describe certificate ingress-cert-${LETSENCRYPT_ENVIRONMENT} -n cert-manager
```
The output should be something similar to:

```
Status:
  Conditions:
    Last Transition Time:  2020-04-12T19:44:17Z
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2020-07-11T18:44:17Z
Events:
  Type    Reason              Age   From          Message
  ----    ------              ----  ----          -------
  Normal  Generated           48m   cert-manager  Generated new private key
  Normal  GenerateSelfSigned  48m   cert-manager  Generated temporary self signed certificate
  Normal  OrderCreated        48m   cert-manager  Created Order resource "ingress-cert-production-2900814068"
  Normal  OrderComplete       46m   cert-manager  Order "ingress-cert-production-2900814068" completed successfully
  Normal  CertIssued          46m   cert-manager  Certificate issued successfully
```

## Install kubed

1. Add kubed helm repository:

```
helm repo add appscode https://charts.appscode.com/stable/
helm repo update
```

2. Install kubed:

```
helm install kubed appscode/kubed --version v0.12.0-rc.2 --namespace kube-system --wait \
  --set apiserver.enabled=false \
  --set config.clusterName=rio
```

Output:

```
NAME: kubed
LAST DEPLOYED: Sun Apr 12 12:34:45 2020
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
To verify that Kubed has started, run:

  kubectl --namespace=kube-system get deployments -l "release=kubed, app=kubed"
```

3. Annotate (mark) the cert-manager secret to be copied to other namespaces if necessary:
```
kubectl annotate secret ingress-cert-${LETSENCRYPT_ENVIRONMENT} -n cert-manager kubed.appscode.com/sync="app=kubed"
```

