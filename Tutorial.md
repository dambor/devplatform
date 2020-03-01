# TMC

1. Creating a cluster

If you are using VMware Tanzu Mission Control to create clusters in AWS, we would like you to grant Tanzu Mission Control slightly more permission in your account using the instructions below. When you registered your AWS account with Tanzu Mission Control, you ran an AWS CloudFormation script to create an IAM role that grants us permission to manage clusters in your account. As part of an effort to harden the security of your clusters, Tanzu Mission Control will start using the AWS Secrets Manager to configure your clusters. Therefore, we need to update our role to grant access to the AWS Secrets Manager to perform CreateSecret, DeleteSecret, GetSecretValue and TagResource operations.
If you are interested in the details, you can see the upstream change to Cluster API to use the secrets manager.
https://github.com/kubernetes-sigs/cluster-api-provider-aws/pull/1490
Please note: Once we update Tanzu Mission Control with this change, currently scheduled for Thursday, February 13th, you will not be able to create new clusters or create new nodepools unless you follow the instructions below.
To secure your TMC provisioned clusters:
1. Save the attached CloudFormation script
2. Log in to the AWS CloudFormation console. https://console.aws.amazon.com/cloudformation
3. Click on “Create Stack” and select “With new resources (standard)”
4. When prompted, click Upload a template file and use the attached template.
5. On the Review page, you must scroll to the bottom and select the checkbox that acknowledges the creation of IAM resources.
6. After a couple of minutes, the Stack details page shows your new stack with the status of CREATE_COMPLETE. You might need to click the refresh button to update the status.
Note 1: you  do not need to change your existing Mission Control CloudFormation stack, just add this new one.
Note 2: If you register new AWS  accounts after February 13th, you can just use the CloudFormation script that Mission Control gives you at the time of registration.
Thanks - VMware Tanzu Mission Control Team
Show less

```
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Resources": {
    "AWSIAMManagedPolicyControllersUpdate": {
      "Type": "AWS::IAM::ManagedPolicy",
      "Properties": {
        "Description": "The managed policy that adds new permissions needed by TMC to perform cluster lifecycle operations",
        "ManagedPolicyName": "controllers-update.tmc.cloud.vmware.com",
        "PolicyDocument": {
          "Statement": [
            {
              "Action": [
                "ec2:*",
                "tag:*",
                "elasticloadbalancing:*"
              ],
              "Effect": "Allow",
              "Resource": [
                "*"]
            },
            {
              "Action": [
                "secretsmanager:CreateSecret",
                "secretsmanager:DeleteSecret",
                "secretsmanager:TagResource"
              ],
              "Effect": "Allow",
              "Resource": [
                "arn:aws:secretsmanager:*:*:secret:aws.cluster.x-k8s.io/*"
              ]
            }
          ],
          "Version": "2012-10-17"
        },
        "Roles": [
          "clusterlifecycle.tmc.cloud.vmware.com"
        ]
      }
    },
    "AWSIAMManagedPolicyControlPlaneUpdate": {
      "Type": "AWS::IAM::ManagedPolicy",
      "Properties": {
        "Description": "The managed policy that adds new permissions for control planes needed by TMC to perform cluster lifecycle operations",
        "ManagedPolicyName": "control-plane-update.tmc.cloud.vmware.com",
        "PolicyDocument": {
          "Statement": [
            {
              "Action": [
                "secretsmanager:DeleteSecret",
                "secretsmanager:GetSecretValue"
              ],
              "Effect": "Allow",
              "Resource": [
                "arn:aws:secretsmanager:*:*:secret:aws.cluster.x-k8s.io/*"]
            }
          ],
          "Version": "2012-10-17"
        },
        "Roles": [
          "control-plane.tmc.cloud.vmware.com"
        ]
      }
    },
    "AWSIAMManagedPolicyNodesUpdate": {
      "Type": "AWS::IAM::ManagedPolicy",
      "Properties": {
        "Description": "The managed policy that adds new permissions for nodes needed by TMC to perform cluster lifecycle operations",
        "ManagedPolicyName": "nodes-update.tmc.cloud.vmware.com",
        "PolicyDocument": {
          "Statement": [
            {
              "Action": [
                "secretsmanager:DeleteSecret",
                "secretsmanager:GetSecretValue"
              ],
              "Effect": "Allow",
              "Resource": [
                "arn:aws:secretsmanager:*:*:secret:aws.cluster.x-k8s.io/*"]
            }
          ],
          "Version": "2012-10-17"
        },
        "Roles": [
          "nodes.tmc.cloud.vmware.com"
        ]
      }
    }
  }

```



2. After creating a Cluster on TMC, you must apply the following policies:

A restrictive pod security policy (https://kubernetes.io/docs/concepts/policy/pod-security-policy/) by default on Kubernetes clusters provisioned through Tanzu Mission Control. This policy will prevent the usage of privileged options in your containers like running the container as root, using privileged mode, hostPath volume mounts, hostNetwork and privileged Linux capabilities. This is done to keep your Kubernetes clusters secure by default.
With that said, some of you might want to use some of these privileged options in your pods. In order to make it easier to use them, we also have a privileged pod security policy. To enable this for a specific pod, you can give the service account it uses the permission to use the privileged pod security policy using the following command:

```
kubectl create rolebinding privileged-role-binding \
    --clusterrole=vmware-system-tmc-psp-privileged \
    --user=system:serviceaccount:<namespace>:<service-account>
```
To enable it for the entire cluster, you can use the following command:
```
kubectl create clusterrolebinding privileged-cluster-role-binding \
    --clusterrole=vmware-system-tmc-psp-privileged \
    --group=system:authenticated
```

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

# ArgoCD



# KNative

## Installing Istio

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