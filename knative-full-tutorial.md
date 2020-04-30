# Install Knative

## Installing the Serving component

1. Install the Custom Resource Definitions (aka CRDs):

```
kubectl delete --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-crds.yaml
```

2. Install the core components of Serving (see below for optional extensions):

```
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-core.yaml
```

3. Install the Knative Istio controller:

```
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-istio.yaml
```

4. Configure DNS with the istio-ingressgateway CNAME

kubectl --namespace istio-system get service istio-ingressgateway

# Here knative.example.com is the domain suffix for your cluster
*.knative.example.com == CNAME a317a278525d111e89f272a164fd35fb-1510370581.eu-central-1.elb.amazonaws.com

5. Once your DNS provider has been configured, direct Knative to use that domain:

# Replace knative.example.com with your domain suffix
kubectl patch configmap/config-domain \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"knative.example.com":""}}'

6. Enable automatic TLS certificate provisioning for Knative

Install networking-certmanager:

kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-cert-manager.yaml

7. Update your config-certmanager ConfigMap in the knative-serving namespace to define your new ClusterIssuer configuration and your your DNS provider:

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-certmanager
  namespace: knative-serving
  labels:
    networking.knative.dev/certificate-provider: cert-manager
data:
  issuerRef: |
    kind: ClusterIssuer
    name: letsencrypt-${LETSENCRYPT_ENVIRONMENT}-dns
  solverConfig: |
    dns01:
      provider: aws-route53
EOF

8. Update the config-network ConfigMap in the knative-serving namespace to enable autoTLS:

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-network
  namespace: knative-serving
data:
  autoTLS: Enabled
  httpProtocol: Enabled
EOF













## Export Knative services 

cat << EOF | kubectl delete -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: knative-faas-gateway
  namespace: knative-serving
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http-faas-services
      protocol: HTTP
    hosts:
    - "*.faas.gdambor.com"
  - port:
      number: 443
      name: https-faas-services
      protocol: HTTPS
    hosts:
    - "*.faas.gdambor.com"
    tls:
      credentialName: ingress-cert-${LETSENCRYPT_ENVIRONMENT}
      mode: SIMPLE
      privateKey: sds
      serverCertificate: sds
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: faas-virtual-service
  namespace: knative-serving
spec:
  hosts:
  - "*.faas.gdambor.com"
  gateways:
  - knative-faas-gateway
  http:
  - route:
    - destination:
        host: service.serving.knative.dev
        port:
          number: 80
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: faas-virtual-service
  namespace: knative-serving
spec:
  hosts:
  - "*.faas.gdambor.com"
  gateways:
  - knative-faas-gateway
  http:
  - route:
    - destination:
        host: service.serving.knative.dev
        port:
          number: 443
EOF


$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: wikipedia
spec:
  hosts:
  - "*.wikipedia.org"
  ports:
  - number: 443
    name: tls
    protocol: TLS
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: wikipedia
spec:
  hosts:
  - "*.wikipedia.org"
  tls:
  - match:
    - port: 443
      sni_hosts:
      - "*.wikipedia.org"
    route:
    - destination:
        host: "*.wikipedia.org"
        port:
          number: 443
EOF


Once your DNS provider has been configured, direct Knative to use that domain:

# Replace knative.example.com with your domain suffix
kubectl patch configmap/config-domain \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"faas.gdambor.com":""}}'







1. Export Prometheus and Grafana
```
cat << EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: knative-services-gateway
  namespace: knative-monitoring
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http-knative-services
      protocol: HTTP
    hosts:
    - knative-grafana.${MY_DOMAIN}
    - knative-prometheus.${MY_DOMAIN}
  - port:
      number: 443
      name: https-knative-services
      protocol: HTTPS
    hosts:
    - knative-grafana.${MY_DOMAIN}
    - knative-prometheus.${MY_DOMAIN}
    tls:
      credentialName: ingress-cert-${LETSENCRYPT_ENVIRONMENT}
      mode: SIMPLE
      privateKey: sds
      serverCertificate: sds
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: grafana-virtual-service
  namespace: knative-monitoring
spec:
  hosts:
  - "knative-grafana.${MY_DOMAIN}"
  gateways:
  - knative-services-gateway
  http:
  - route:
    - destination:
        host: grafana.knative-monitoring.svc.cluster.local
        port:
          number: 30802
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: prometheus-virtual-service
  namespace: knative-monitoring
spec:
  hosts:
  - "knative-prometheus.${MY_DOMAIN}"
  gateways:
  - knative-services-gateway
  http:
  - route:
    - destination:
        host: prometheus-system-np.knative-monitoring.svc.cluster.local
        port:
          number: 8080
EOF
```
2. Set up a custom domain for Knative:

```
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-domain
  namespace: knative-serving
data:
  ${MY_DOMAIN}: "faas"
EOF
```

Changing the controller deployment is needed if you are not using the valid certificates (self-signed):

if [ ${LETSENCRYPT_ENVIRONMENT} = "staging" ]; then
  kubectl --namespace knative-serving create secret generic customca --from-file=customca.crt=/tmp/fakelerootx1.pem
  kubectl patch deployment controller --namespace knative-serving --patch "
    {
        \"spec\": {
            \"template\": {
                \"spec\": {
                    \"containers\": [{
                        \"env\": [{
                            \"name\": \"SSL_CERT_DIR\",
                            \"value\": \"/etc/customca\"
                        }],
                        \"name\": \"controller\",
                        \"volumeMounts\": [{
                            \"mountPath\": \"/etc/customca\",
                            \"name\": \"customca\"
                        }]
                    }],
                    \"volumes\": [{
                        \"name\": \"customca\",
                        \"secret\": {
                            \"defaultMode\": 420,
                            \"secretName\": \"customca\"
                        }
                    }]
                }
            }
        }
    }"
fi

## Enable automatic TLS certificate provisioning for Knative

1. Install networking-certmanager: 
```
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-cert-manager.yaml
````

2. Update your config-certmanager ConfigMap in the knative-serving namespace to define your new ClusterIssuer configuration and your your DNS provider:

```
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-certmanager
  namespace: knative-serving
  labels:
    networking.knative.dev/certificate-provider: cert-manager
data:
  issuerRef: |
    kind: ClusterIssuer
    name: letsencrypt-${LETSENCRYPT_ENVIRONMENT}-dns
  solverConfig: |
    dns01:
      provider: aws-route53
EOF
```

3. Update the config-network ConfigMap in the knative-serving namespace to enable autoTLS:

```
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-network
  namespace: knative-serving
data:
  autoTLS: Enabled
  httpProtocol: Enabled
EOF
```