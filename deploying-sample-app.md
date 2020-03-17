# Deploying a Sample Application to Knative

## Configuring your deployment

To deploy an app using Knative, you need a configuration .yaml file that defines a Service. For more information about the Service object, see the Resource Types documentation. https://github.com/knative/serving/blob/master/docs/spec/overview.md#service

This configuration file specifies metadata about the application, points to the hosted image of the app for deployment, and allows the deployment to be configured. For more information about what configuration options are available, see the Serving spec documentation. https://github.com/knative/serving/blob/master/docs/spec/spec.md

1. Create a new file named hello-world.yaml, then copy and paste the following content into it:

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

1. From the directory where the new helloworld-go.yaml file was created, apply the configuration:

```kubectl apply --filename helloworld-go.yaml```

Now that your service is created, Knative will perform the following steps:

* Create a new immutable revision for this version of the app.
* Perform network programming to create a route, ingress, service, and load balancer for your app.
* Automatically scale your pods up and down based on traffic, including to zero active pods.

2. To find the URL for your service, enter:

```kubectl get ksvc helloworld-go.yaml```

The command will return the following:

```
NAME         URL                                            LATESTCREATED      LATESTREADY        READY   REASON
demo-cloud   http://demo-cloud.default.172.17.0.20.xip.io   demo-cloud-gsjxl   demo-cloud-gsjxl   True
```


3. Now you can make a request to your app and see the results. Replace the URL with the one returned by the command in the previous step.
```
# curl http://helloworld-go.default.<KNATIVE-DNS>
Hello!!!
```
