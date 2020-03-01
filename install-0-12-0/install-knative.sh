kubectl apply --selector knative.dev/crd-install=true \
--filename serving.yaml \
--filename eventing.yaml \
--filename monitoring.yaml

kubectl apply --filename serving.yaml \
--filename eventing.yaml \
--filename monitoring.yaml

kubectl get pods --namespace knative-serving
kubectl get pods --namespace knative-eventing
kubectl get pods --namespace knative-monitoring
