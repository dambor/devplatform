# KPack

KPack requires you to have a Docker Repo available. In this tutorial we're assuming you have a DockerHub account.

1. Apply the latest kpack release:

```
kubectl apply  --filename kpack/release-0.0.6.yaml
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
  image: cloudfoundry/cnb:0.0.55-bionic
```

4. Apply the ClusterBuilder yaml to the cluster

```
kubectl apply -f kpack/cluster-builder.yaml
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
  name: registry-credentials
  annotations:
    build.pivotal.io/docker: <registry-prefix> # use https://index.docker.io/v1/ for dockerhub
type: kubernetes.io/basic-auth
stringData:
  username: <username>
  password: <password>
```

2. Apply that credential to the cluster

```
kubectl apply -f registry-credentials.yaml
```

3. Create a service account that references the registry secret created above
```
apiVersion: v1
kind: ServiceAccount
metadata:
 name: kpack-service-account
secrets:
 - name: registry-credentials
```
4. Apply that service account to the cluster

```
kubectl apply -f kpack-service-account.yaml
```

5. Apply a kpack image configuration

An image configuration is the specification for an image that kpack should build and manage. We will create a sample image that builds with the default builder setup in the installing documentation. 

```
git clone https://github.com/dambor/spring-petclinic
```

Create an image configuration:
```
apiVersion: build.pivotal.io/v1alpha1
kind: Image
metadata:
  name: petclinic-image
spec:
  tag: <YOUR-DOCKER-REG>/petclinic
  serviceAccount: kpack-service-account
  cacheSize: "1.5Gi"
  builder:
    name: default
    kind: ClusterBuilder
  source:
    git:
      url: https://github.com/<YOUR-GITHUB>/spring-petclinic
      revision: 7387637a4d9d271ea6de0c884e8877e8b176d650
```
Make sure to replace the <tag> with the registry you configured in step #2. Something like: your-name/app or gcr.io/your-project/app
If you are using your application source, replace source.git.url & source.git.revision. You can check your application review using `git rev-parse HEAD` command.

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
logs -image petclinic-image  
```

9. Once the image finishes building you can get the fully resolved built image with ```kubectl get```
```
kubectl get image petclinic-image
````
