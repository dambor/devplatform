# KNative

## Installing Knative

The following commands install all available Knative components. To customize your Knative installation, see Performing a Custom Knative Installation.

1. To install Knative, first install the CRDs by running the kubectl apply command once with the -l knative.dev/crd-install=true flag. This prevents race conditions during the install, which cause intermittent errors:

```
kubectl apply --selector knative.dev/crd-install=true \
--filename https://github.com/knative/serving/releases/download/v0.12.0/serving.yaml \
--filename https://github.com/knative/eventing/releases/download/v0.12.0/eventing.yaml \
--filename https://github.com/knative/serving/releases/download/v0.12.0/monitoring.yaml
```


2. To complete the install of Knative and its dependencies, run the kubectl apply command again, this time without the --selector flag, to complete the install of Knative and its dependencies:

```
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.12.0/serving.yaml \
--filename https://github.com/knative/eventing/releases/download/v0.12.0/eventing.yaml \
--filename https://github.com/knative/serving/releases/download/v0.12.0/monitoring.yaml
```

3. Monitor the Knative components until all of the components show a STATUS of Running:

```
kubectl get pods --namespace knative-serving
kubectl get pods --namespace knative-eventing
kubectl get pods --namespace knative-monitoring
```

4. Configuring DNS

Knative dispatches to different services based on their hostname, so it greatly simplifies things to have DNS properly configured. For this, we must look up the external IP address that istio-ingressgateway received. This can be done with the following command:

```
$ kubectl get svc -nistio-system
NAME                    TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)                                      AGE
cluster-local-gateway   ClusterIP      10.0.2.216   <none>         15020/TCP,80/TCP,443/TCP                     2m14s
istio-ingressgateway    LoadBalancer   10.0.2.24    34.83.80.117   15020:32206/TCP,80:30742/TCP,443:30996/TCP   2m14s
istio-pilot             ClusterIP      10.0.3.27    <none>         15010/TCP,15011/TCP,8080/TCP,15014/TCP       2m14s
```

This external IP can be used with your DNS provider with a wildcard A record; however, for a basic functioning DNS setup (not suitable for production!) this external IP address can be used with xip.io in the config-domain ConfigMap in knative-serving. You can edit this with the following command:

```kubectl edit cm config-domain --namespace knative-serving```

Given the external IP above, change the content to:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-domain
  namespace: knative-serving
data:
  # xip.io is a "magic" DNS provider, which resolves all DNS lookups for:
  # *.{ip}.xip.io to {ip}.
  34.83.80.117.xip.io: ""
```
## Sample Application: Deploying SpringBoot on Knative

### Configuring your deployment

To deploy an app using Knative, you need a configuration .yaml file that defines a Service. For more information about the Service object, see the Resource Types documentation. https://github.com/knative/serving/blob/master/docs/spec/overview.md#service

This configuration file specifies metadata about the application, points to the hosted image of the app for deployment, and allows the deployment to be configured. For more information about what configuration options are available, see the Serving spec documentation. https://github.com/knative/serving/blob/master/docs/spec/spec.md

1. Create a new file named demo-cloud.yaml, then copy and paste the following content into it:

```
apiVersion: serving.knative.dev/v1 # Current version of Knative
kind: Service
metadata:
  name: helloworld-go # The name of the app
  namespace: default # The namespace the app will use
spec:
  template:
    spec:
      containers:
        - image: gcr.io/knative-samples/helloworld-go # The URL to the image of the app
          env:
            - name: TARGET # The environment variable printed out by the sample app
              value: "Go Sample v1"
```

If you want to deploy the sample app, leave the config file as-is. If you're deploying an image of your own app, update the name of the app and the URL of the image accordingly.

### Deploying your app

1. From the directory where the new demo-cloud.yaml file was created, apply the configuration:

```kubectl apply --filename demo-cloud.yaml```

Now that your service is created, Knative will perform the following steps:

* Create a new immutable revision for this version of the app.
* Perform network programming to create a route, ingress, service, and load balancer for your app.
* Automatically scale your pods up and down based on traffic, including to zero active pods.

2. To find the URL for your service, enter:

```kubectl get ksvc demo-cloud```

The command will return the following:

```
NAME         URL                                            LATESTCREATED      LATESTREADY        READY   REASON
demo-cloud   http://demo-cloud.default.172.17.0.20.xip.io   demo-cloud-gsjxl   demo-cloud-gsjxl   True
```


3. Now you can make a request to your app and see the results. Replace the URL with the one returned by the command in the previous step.
```
# curl http://demo-cloud.default.172.17.0.20.xip.io/hi
Hello!!!
```
