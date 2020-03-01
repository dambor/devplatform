# Istio

When you install Istio, there are a few options depending on your goals. For a basic Istio installation suitable for most Knative use cases, we're going to install Istio without sidecar injection instructions. 

### Downloading Istio and installing CRDs
Enter the following commands to download Istio:

1. Download and unpack Istio
```
export ISTIO_VERSION=1.3.5
curl -L https://git.io/getLatestIstio | sh -
cd istio-${ISTIO_VERSION}
```

2. Enter the following command to install the Istio CRDs first:

```
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
```

Wait a few seconds for the CRDs to be committed in the Kubernetes API-server, then continue with these instructions.

3. Create istio-system namespace
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
  labels:
    istio-injection: disabled
EOF
```

4. Installing Istio without sidecar injection

In order to get up and running with Knative quickly, we're installing Istio without automatic sidecar injection. This install is also recommended for users who don't need the Istio service mesh, or who want to enable the service mesh by manually injecting the Istio sidecars.

Enter the following command to install Istio:
```
# A lighter template, with just pilot/gateway.
# Based on install/kubernetes/helm/istio/values-istio-minimal.yaml
helm template --namespace=istio-system \
  --set prometheus.enabled=false \
  --set mixer.enabled=false \
  --set mixer.policy.enabled=false \
  --set mixer.telemetry.enabled=false \
  `# Pilot doesn't need a sidecar.` \
  --set pilot.sidecar=false \
  --set pilot.resources.requests.memory=128Mi \
  `# Disable galley (and things requiring galley).` \
  --set galley.enabled=false \
  --set global.useMCP=false \
  `# Disable security / policy.` \
  --set security.enabled=false \
  --set global.disablePolicyChecks=true \
  `# Disable sidecar injection.` \
  --set sidecarInjectorWebhook.enabled=false \
  --set global.proxy.autoInject=disabled \
  --set global.omitSidecarInjectorConfigMap=true \
  --set gateways.istio-ingressgateway.autoscaleMin=1 \
  --set gateways.istio-ingressgateway.autoscaleMax=2 \
  `# Set pilot trace sampling to 100%` \
  --set pilot.traceSampling=100 \
  install/kubernetes/helm/istio \
  > ./istio-lean.yaml
```
Apply the istio-lean.yaml file:
```
kubectl apply -f istio-lean.yaml
```
5. Verifying your Istio install

View the status of your Istio installation to make sure the install was successful. It might take a few seconds, so rerun the following command until all of the pods show a STATUS of Running or Completed:

```
kubectl get pods --namespace istio-system
```

