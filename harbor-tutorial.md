# Harbor

1. Label Harbor namespace and copy there the secret with certificates signed by Let's Encrypt certificate:

```
kubectl create namespace harbor
kubectl label namespace harbor app=kubed
```

2. Create Istio Gateways and VirtualServices to allow accessing Harbor from "outside":

cat << EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: harbor-gateway
  namespace: harbor
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http-harbor
      protocol: HTTP
    hosts:
    - myharbor.${MY_DOMAIN}
  - port:
      number: 443
      name: https-harbor
      protocol: HTTPS
    hosts:
    - myharbor.${MY_DOMAIN}
    - notary.${MY_DOMAIN}
    tls:
      mode: PASSTHROUGH
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: harbor-http-virtual-service
  namespace: harbor
spec:
  hosts:
  - myharbor.${MY_DOMAIN}
  gateways:
  - harbor-gateway
  http:
  - match:
    - port: 80
    route:
    - destination:
        host: harbor.harbor.svc.cluster.local
        port:
          number: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: harbor-https-virtual-service
  namespace: harbor
spec:
  hosts:
  - myharbor.${MY_DOMAIN}
  gateways:
  - harbor-gateway
  tls:
  - match:
    - port: 443
      sniHosts:
      - myharbor.${MY_DOMAIN}
    route:
    - destination:
        host: harbor.harbor.svc.cluster.local
        port:
          number: 443
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: harbor-notary-virtual-service
  namespace: harbor
spec:
  hosts:
  - notary.${MY_DOMAIN}
  gateways:
  - harbor-gateway
  tls:
  - match:
    - port: 443
      sniHosts:
      - notary.${MY_DOMAIN}
    route:
    - destination:
        host: harbor.harbor.svc.cluster.local
        port:
          number: 4443
EOF

3. Add Harbor Helm repository:

```
helm repo add harbor https://helm.goharbor.io
helm repo update
```

4. Install Harbor using Helm:

helm install harbor harbor/harbor --namespace harbor --version v1.3.0 --wait \
  --set expose.tls.enabled=true \
  --set expose.tls.secretName=ingress-cert-${LETSENCRYPT_ENVIRONMENT} \
  --set expose.type=clusterIP \
  --set externalURL=https://myharbor.${MY_DOMAIN} \
  --set harborAdminPassword=admin \
  --set persistence.enabled=false


















1. Set up the MY_DOMAIN variable containing domain and LETSENCRYPT_ENVIRONMENT variable. The LETSENCRYPT_ENVIRONMENT variable should be one of:

* staging - Let’s Encrypt will create testing certificate (not valid)
* production - Let’s Encrypt will create valid certificate (use with care)

```
export MY_DOMAIN=${MY_DOMAIN:-mylabs.dev}
export LETSENCRYPT_ENVIRONMENT=${LETSENCRYPT_ENVIRONMENT:-staging}
echo "${MY_DOMAIN} | ${LETSENCRYPT_ENVIRONMENT}"
```

## Install Cert Manager

2. Install the CRDs separately:

```
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.10/deploy/manifests/00-crds.yaml
```

3. Create the namespace for cert-manager and label it to disable resource validation:

```
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
```

4. Install the cert-manager Helm chart:

```
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager --namespace cert-manager --wait jetstack/cert-manager --version v0.10.1
```






## Create ClusterIssuer for Let's Encrypt

1. Create ClusterIssuer for Route53 used by cert-manager. It will allow Let's Encrypt to generate certificate. Route53 (DNS) method of requesting certificate from Let's Encrypt must be used to create wildcard certificate *.mylabs.dev (details here).

Make sure to:

```
export USER_AWS_ACCESS_KEY_ID=<USER_ID>
export USER_AWS_SECRET_ACCESS_KEY=<SECRET_KEY>
```

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
          region: eu-central-1
          secretAccessKeySecretRef:
            name: aws-user-secret-access-key-secret
            key: secret-access-key
EOF
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
          region: eu-central-1
          secretAccessKeySecretRef:
            name: aws-user-secret-access-key-secret
            key: secret-access-key
EOF
```


kubectl create secret docker-registry goharbor-docker-config \
  --docker-server=goharbor.gdambor.com \
  --docker-username=admin \
  --docker-password=admin