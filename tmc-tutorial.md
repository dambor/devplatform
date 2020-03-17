# Tanzu Mission Control

In this tutorial we're going to demonstrate how to login to Tanzu Mission Control and create a Kubernetes cluster on AWS both using the TMC Command Line Interface.

## TMC Login

1. Login to the tmc 

```
➜  ~ tmc login
ℹ To fetch an API token visit https://console.cloud.vmware.com/csp/gateway/portal/#/user/tokens
✔ API token: 
```

2. Give a name to your context:

```
✔ Login context name:
```

3. Select the log level:

```
? Select default log level  [Use arrows to move, type to filter]
  none
  critical
  warning
> info
  debug
```
4. Choose your credential:

```
? Select default credential  [Use arrows to move, type to filter]
```
5. Choose the region you want your cluster to be deployed:

```
? Select default region  [Use arrows to move, type to filter]
> us-east-1
  us-east-2
  us-west-1
  us-west-2
  eu-west-1
  eu-central-1
  ap-southeast-1
```
6. Select the AWS SSH key:
```
? Select default AWS SSH key  [Use arrows to move, type to filter]
> tmc-key-pair
```
7. You should see the message below:

```
✔ Successfully created context "dambor", to manage your contexts run `tmc system context -h`
````
## Creating a Kubernetes cluster

1. Creating a cluster using the wizard

```
# create a cluster with the wizard
  tmc cluster create -w
```

```
➜  ~ tmc cluster create -w
? Cluster Name knative
? Nodepool Name nodes
? Select default credential PA-gborges
? Select default region us-east-1
? Select default AWS SSH key tmc-key-pair
? Select the kubernetes version 1.17.2-1-amazon2
? Select cluster group dambor
? Labels
✔ cluster "knative" created successfully

```

2. Or if you prefer you can use a single line command:

```
tmc cluster create -n knative -q 2 -r us-east-1 -g <YOUR-CLUSTER-GROUP>
```
3. At the end of the cluster creation you should be able to see this output:

```
➜  ~ tmc cluster list | grep knative
  knative                        dambor                    AWS_EC2         PROVISIONED  READY     HEALTHY       tmc.cloud.vmware.com/creator:gborges_pivotal.io
```
## Accessing the cluster created:

1. Download the kubeconfig to a file:

```
➜  ~ tmc cluster provisionedcluster kubeconfig get knative > /FILE_PATH/kubeconfig-knative.yml
```
2. Export the KUBECONFIG variable:

```
export KUBECONFIG=/FILE_PATH/kubeconfig-knative.yml
kubectl cluster-info
```

3. You are now logged into the the cluster and can see all resources with the following command:

```
➜  ~ kubectl get all -A
```

## Additional configurations

1. After creating a Cluster on TMC, you must apply the following policies:

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





