# Velero plugins for AWS

## Overview

This repository contains these plugins to support running Velero on AWS:

- An object store plugin for persisting and retrieving backups on AWS S3. Content of backup is log files, warning/error files, restore logs.

- A volume snapshotter plugin for creating snapshots from volumes (during a backup) and volumes from snapshots (during a restore) on AWS EBS.

## Compatibility

Below is a listing of plugin versions and respective Velero versions that are compatible.

| Plugin Version  | Velero Version |
|-----------------|----------------|
| v1.0.x          | v1.3.x         |
| v1.0.x          | v1.2.0         |


## Setup

To set up Velero on AWS, you:

* [Create an S3 bucket][1]
* [Set permissions for Velero][2]
* [Install and start Velero][3]
* [Migrating PVs across clusters][5]

If you do not have the `aws` CLI locally installed, follow the [user guide][6] to set it up.

## Create S3 bucket

Velero requires an object storage bucket to store backups in, preferably unique to a single Kubernetes cluster (see the [FAQ][11] for more details). Create an S3 bucket, replacing placeholders appropriately:

```bash
BUCKET=<YOUR_BUCKET>
REGION=<YOUR_REGION>
aws s3api create-bucket \
    --bucket $BUCKET \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION
```
NOTE: us-east-1 does not support a `LocationConstraint`.  If your region is `us-east-1`, omit the bucket configuration:

```bash
aws s3api create-bucket \
    --bucket $BUCKET \
    --region us-east-1
```

## Set permissions for Velero

### Option 1: Set permissions with an IAM user

For more information, see [the AWS documentation on IAM users][10].

1. Create the IAM user:

    ```bash
    aws iam create-user --user-name velero
    ```

    If you'll be using Velero to backup multiple clusters with multiple S3 buckets, it may be desirable to create a unique username per cluster rather than the default `velero`.

2. Attach policies to give `velero` the necessary permissions:

    ```
    cat > velero-policy.json <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:DescribeVolumes",
                    "ec2:DescribeSnapshots",
                    "ec2:CreateTags",
                    "ec2:CreateVolume",
                    "ec2:CreateSnapshot",
                    "ec2:DeleteSnapshot"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:DeleteObject",
                    "s3:PutObject",
                    "s3:AbortMultipartUpload",
                    "s3:ListMultipartUploadParts"
                ],
                "Resource": [
                    "arn:aws:s3:::${BUCKET}/*"
                ]
            },
            {
                "Effect": "Allow",
                "Action": [
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::${BUCKET}"
                ]
            }
        ]
    }
    EOF
    ```
    ```bash
    aws iam put-user-policy \
      --user-name velero \
      --policy-name velero \
      --policy-document file://velero-policy.json
    ```

3. Create an access key for the user:

    ```bash
    aws iam create-access-key --user-name velero
    ```

    The result should look like:

    ```json
    {
      "AccessKey": {
            "UserName": "velero",
            "Status": "Active",
            "CreateDate": "2017-07-31T22:24:41.576Z",
            "SecretAccessKey": <AWS_SECRET_ACCESS_KEY>,
            "AccessKeyId": <AWS_ACCESS_KEY_ID>
      }
    }
    ```

4. Create a Velero-specific credentials file (`credentials-velero`) in your local directory:

    ```bash
    [default]
    aws_access_key_id=<AWS_ACCESS_KEY_ID>
    aws_secret_access_key=<AWS_SECRET_ACCESS_KEY>
    ```

    where the access key id and secret are the values returned from the `create-access-key` request.

## Install and start Velero

[Download][4] Velero

Install Velero, including all prerequisites, into the cluster and start the deployment. This will create a namespace called `velero`, and place a deployment named `velero` in it.

**If using IAM user and access key**:

```bash
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.0.1 \
    --bucket $BUCKET \
    --backup-location-config region=$REGION \
    --snapshot-location-config region=$REGION \
    --secret-file ./credentials-velero
```

## Migrating PVs across clusters

### Setting AWS_CLUSTER_NAME (Optional)

If you have multiple clusters and you want to support migration of resources between them, you can use `kubectl edit deploy/velero -n velero` to edit your deployment:

Add the environment variable `AWS_CLUSTER_NAME` under `spec.template.spec.env`, with the current cluster's name. When restoring backup, it will make Velero (and cluster it's running on) claim ownership of AWS volumes created from snapshots taken on different cluster.
The best way to get the current cluster's name is to either check it with used deployment tool or to read it directly from the EC2 instances tags.

The following listing shows how to get the cluster's nodes EC2 Tags. First, get the nodes external IDs (EC2 IDs):

```bash
kubectl get nodes -o jsonpath='{.items[*].spec.externalID}'
```

Copy one of the returned IDs `<ID>` and use it with the `aws` CLI tool to search for one of the following:

  * The `kubernetes.io/cluster/<AWS_CLUSTER_NAME>` tag of the value `owned`. The `<AWS_CLUSTER_NAME>` is then your cluster's name:

    ```bash
    aws ec2 describe-tags --filters "Name=resource-id,Values=<ID>" "Name=value,Values=owned"
    ```

  * If the first output returns nothing, then check for the legacy Tag `KubernetesCluster` of the value `<AWS_CLUSTER_NAME>`:

    ```bash
    aws ec2 describe-tags --filters "Name=resource-id,Values=<ID>" "Name=key,Values=KubernetesCluster"
    ```


[1]: #Create-S3-bucket
[2]: #Set-permissions-for-Velero
[3]: #Install-and-start-Velero
[4]: https://velero.io/docs/install-overview/
[5]: #Migrating-PVs-across-clusters
[6]: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html
[7]: backupstoragelocation.md
[8]: volumesnapshotlocation.md
[9]: https://velero.io/docs/customize-installation/
[10]: http://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html
[11]: https://velero.io/docs/faq/


Reference: https://github.com/vmware-tanzu/velero-plugin-for-aws#setup