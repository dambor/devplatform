# KPack

1. Download the most recent github release (https://github.com/pivotal/kpack/releases). The release.yaml is an asset on the release.

```
kubectl apply  --filename release-<version>.yaml
```

2. Ensure that the kpack controller & webhook have a status of Running using kubectl get.

```
kubectl get pods --namespace kpack --watch
```

3. Create a ClusterBuilder resource. A ClusterBuilder is a reference to a Cloud Native Buildpacks builder image. The Builder image contains buildpacks that will be used to build images with kpack. We recommend starting with the cloudfoundry/cnb:bionic image which has support for Java, Node and Go.
```
apiVersion: build.pivotal.io/v1alpha1
kind: ClusterBuilder
metadata:
  name: default
spec:
  image: cloudfoundry/cnb:bionic
```

4. Apply the ClusterBuilder yaml to the cluster

```
kubectl apply -f cluster-builder.yaml
```

5. Ensure that kpack has processed the builder by running

```
kubectl describe clusterbuilder default
```



## Deploying an Image


1. Create a secret with push credentials for the docker registry that you plan on publishing images to with kpack.

```
apiVersion: v1
kind: Secret
metadata:
  name: tutorial-registry-credentials
  annotations:
    build.pivotal.io/docker: <registry-prefix>
type: kubernetes.io/basic-auth
stringData:
  username: <username>
  password: <password>
```

2. Apply that credential to the cluster

```
kubectl apply -f secret.yaml
```

3. Create a service account that references the registry secret created above
```
apiVersion: v1
kind: ServiceAccount
metadata:
 name: tutorial-service-account
secrets:
 - name: tutorial-registry-credentials
```
4. Apply that service account to the cluster

```
kubectl apply -f service-account.yaml
```

5. Apply a kpack image configuration

An image configuration is the specification for an image that kpack should build and manage.

We will create a sample image that builds with the default builder setup in the installing documentation.

The example included here utilizes the Spring Pet Clinic sample app. We encourage you to substitute it with your own application.

Create an image configuration:
```
apiVersion: build.pivotal.io/v1alpha1
kind: Image
metadata:
  name: tutorial-image
spec:
  tag: <DOCKER-IMAGE>
  serviceAccount: tutorial-service-account
  cacheSize: "1.5Gi"
  builder:
    name: default
    kind: ClusterBuilder
  source:
    git:
      url: https://github.com/spring-projects/spring-petclinic
      revision: 82cb521d636b282340378d80a6307a08e3d4a4c4
```
Make sure to replace <DOCKER-IMAGE> with the registry you configured in step #2. Something like: your-name/app or gcr.io/your-project/app
If you are using your application source, replace source.git.url & source.git.revision.

6. Apply that image to the cluster

```
kubectl apply -f <name-of-image-file.yaml>
```

7. You can now check the status of the image.

```
kubectl get images 
```

8. Download the `log` utility: https://github.com/pivotal/kpack/blob/master/docs/logs.md. You can tail the logs for image that is currently building using the logs utility

```
logs -image tutorial-image  
```

9. Once the image finishes building you can get the fully resolved built image with ```kubectl get```
```
kubectl get image tutorial-image
````
