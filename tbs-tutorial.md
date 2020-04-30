# Tanzu Build Service

## Pre Requisites

Prerequisites
Before you install Build Service, you must:

1. Ensure your Kubernetes cluster is configured with PersistentVolumes. Configure the cache size per image to 2 GB. Build Service utilizes PersistentVolumeClaims to cache build artifacts, which reduces the time of subsequent builds. For more information, see Persistent Volumes[https://kubernetes.io/docs/concepts/storage/persistent-volumes/] in the Kubernetes documentation.

2. Download the Duffle executable for your operating system from the Tanzu Build Service (https://network.pivotal.io/products/build-service/) page on Tanzu Network.

3. Download the Build Service Bundle from the Tanzu Build Service https://network.pivotal.io/products/build-service/ page on Tanzu Network.

4. Download the Build Service Dependencies from the Tanzu Build Service Dependencies https://network.pivotal.io/products/tbs-dependencies/ page on Tanzu Network.

## Preparing the Config File

1. Generate a new config file based on TMC config using the following command:

```
cd tbs/create-sa/
```

```
./create_sa.sh tbsautomation default
```

Output:

```
Creating target directory to hold files in /tmp/kube...done
Creating a service account in default namespace: tbsautomation
serviceaccount/tbsautomation created

Getting secret of service account tbsautomation on default
Secret name: tbsautomation-token-579fn

Extracting ca.crt from secret...done
Getting user token from secret...done
Setting current context to: rio
Cluster name: rio
 Endpoint: https://4m85zuxlbaiksklyisrvlibxhw3s-k8s-2124276683.us-east-1.elb.amazonaws.com:443

Preparing k8s-tbsautomation-default-conf
Setting a cluster entry in kubeconfig...Cluster "rio" set.
Setting token credentials entry in kubeconfig...User "tbsautomation-default-rio" set.
Setting a context entry in kubeconfig...Context "tbsautomation-default-rio" created.
Setting the current-context in the kubeconfig file...Switched to context "tbsautomation-default-rio".

Applying RBAC permissions...sed: permissions-template.yaml: No such file or directory

```

2. Navigate to the /tmp folder and create a file named credentials.yml.

Add the properties shown in the example below to the credentials.yml file:

```
export CONFIG_FILE="/tmp/kube/k8s-tbsautomation-default-conf"
export CA_FILE="/tmp/kube/ca.crt"
```

```
echo "name: build-service-credentials
credentials:
 - name: kube_config
   source:
     path: "${CONFIG_FILE}"
   destination:
     path: "/root/.kube/config"
 - name: ca_cert
   source:
     path: "${CA_FILE}"
   destination:
     path: "/cnab/app/cert/ca.crt"" > /tmp/credentials.yml
```


## Relocate Images to a Registry

1. Log in to harbor web interface and create a `${HARBOR_PROJECT}` project where you're going to relocate the TBS images

2. On a terminal, login to harbor using docker cli:

```
export IMAGE_REGISTRY=myharbor.gdambor.com
export HARBOR_PROJECT=build-service
export TBS_VERSION=0.1.0

docker login ${IMAGE_REGISTRY} 
```

3. Push the images to the image registry by running:

```
duffle relocate -f /tmp/build-service-${TBS_VERSION}.tgz -m /tmp/relocated.json -p ${IMAGE_REGISTRY}/${HARBOR_PROJECT}
```

## Run Duffle Install

1. Use Duffle to install Build Service and define the required Build Service parameters by running:
```
export TBS_INSTALLATION_NAME=tbs
export CLUSTER_NAME=rio
export REGISTRY_USERNAME=admin
export REGISTRY_PASSWORD=admin
export BUILDER_IMAGE_TAG=myharbor.gdambor.io/${HARBOR_PROJECT}/default-builder
export ADMIN_USERS=admin
```
```
duffle install ${TBS_INSTALLATION_NAME} -c /tmp/credentials.yml  \
    --set kubernetes_env=${CLUSTER_NAME} \
    --set docker_registry=${IMAGE_REGISTRY} \
    --set registry_username=${REGISTRY_USERNAME} \
    --set registry_password=${REGISTRY_PASSWORD} \
    --set custom_builder_image=${BUILDER_IMAGE_TAG} \
    --set admin_users=${ADMIN_USERS} \
    -f /tmp/build-service-${TBS_VERSION}.tgz \
    -m /tmp/relocated.json
```

duffle install tbs-beta -c /tmp/credentials.yml  \
    --set kubernetes_env=rio \
    --set docker_registry=myharbor.gdambor.com \
    --set registry_username=admin \
    --set registry_password=admin \
    --set custom_builder_image=myharbor.gdambor.io/build-service/default-builder \
    --set admin_users=admin \
    -f /tmp/build-service-0.1.0.tgz \
    -m /tmp/relocated.json



If you need to retry make sure to delete previous duffle executions:

```
rm -rf ~/.duffle/claims/*
```

## Verify Installation

Verify your Build Service installation by first targeting the cluster Build Service has been installed on.

To verify your Build Service installation:

Download the pb binary from the Tanzu Build Service https://network.pivotal.io/products/build-service/ page on Tanzu Network.

List the builders available in your installation:

pb builder list

You should see an output that looks as follows:
```
Cluster Builders
----------------
default
```

Other useful commands:

```
pb stack status
pb store list
pb builder status default --cluster
```

## Creating a project

1. Create and target your project first:

```
pb project create development
pb project target development
```

2. Create a new namespace where you want to deploy the images

```
kubectl create ns images
kubectl config set-context --current --namespace=images
```

3. Create GitHub and Harbor secrets:

```
pb secrets registry apply -f tbs/secrets/configure-registry.yaml
pb secrets git apply -f tbs/secrets/configure-repo.yaml
```

4. Create an Image (two examples - a Spring Boot one and a PHP one):

```
pb image apply -f tbs/secrets/petclinic-image.yaml 
```

5. To check the status of the image and the builds do the following:


```
pb image list
```

Output:

```
Project: development

Images
------
myharbor.gdambor.com/spring/petclinic:latest
```
 
Other commands:

```
pb image status myharbor.gdambor.com/spring/petclinic
pb image logs myharbor.gdambor.com/spring/petclinic -b 1 -f
```

6. To delete an image:
```
pb image delete myharbor.gdambor.com/spring/petclinic
```

## Uninstall TBS

1. To uninstall TBS:

```
duffle uninstall build-service -c /tmp/credentials.yml -m /tmp/relocated.json
```