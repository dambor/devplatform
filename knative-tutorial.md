# KNative


The following commands install the Knative Serving component. This demo doesn't include the Eventing component.

1. Install the Custom Resource Definitions (aka CRDs):

```
kubectl apply --filename knative-serving/serving-crds.yaml
```
2. Install the core components of Serving (see below for optional extensions):

```
kubectl apply --filename knative-serving/serving-core.yaml
```

# Install Contour

The following commands install Contour and enable its Knative integration.

1. Install a properly configured Contour:

```
kubectl apply --filename contour/contour.yaml
```

2. Install the Knative Contour controller:

```
kubectl apply --filename contour/net-contour.yaml
```

3. To configure Knative Serving to use Contour by default:

```
kubectl patch configmap/config-network \
      --namespace knative-serving \
      --type merge \
      --patch '{"data":{"ingress.class":"contour.ingress.networking.knative.dev"}}'
```

4. Fetch the External IP or CNAME:

```
kubectl --namespace contour-external get service envoy
```

Save this for configuring DNS below.

# Configure DNS


1. To configure DNS for Knative, take the External IP or CNAME from setting up networking, and configure it with your DNS provider as follows:

* If the networking layer produced an External IP address, then configure a wildcard A record for the domain:

```
# Here knative.example.com is the domain suffix for your cluster
*.knative.example.com == A 35.233.41.212
```

* If the networking layer produced a CNAME, then configure a CNAME record for the domain:

```
# Here knative.example.com is the domain suffix for your cluster
*.knative.example.com == CNAME a317a278525d111e89f272a164fd35fb-1510370581.eu-central-1.elb.amazonaws.com
```

2. Once your DNS provider has been configured, direct Knative to use that domain:

```
# Replace knative.example.com with your domain suffix
kubectl patch configmap/config-domain \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"knative.example.com":""}}'
```

3. Monitor the Knative components until all of the components show a STATUS of Running or Completed:

```
kubectl get pods --namespace knative-serving
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
