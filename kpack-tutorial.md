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

