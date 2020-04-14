# Prepare AWS Environment  


1. Setting up the env variable

```
export MY_DOMAIN=gdambor.com
export LETSENCRYPT_ENVIRONMENT=production
export USER=dambor
```

* staging - Let’s Encrypt will create testing certificate (not valid)
* production - Let’s Encrypt will create valid certificate (use with care)

```
export MY_DOMAIN=${MY_DOMAIN:-gdambor.com}
export LETSENCRYPT_ENVIRONMENT=${LETSENCRYPT_ENVIRONMENT:-production}
echo "${MY_DOMAIN} | ${LETSENCRYPT_ENVIRONMENT}"
```

## Configure AWS

1. Authorize to AWS using AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html

```
aws configure
...
```

2. Create DNS zone:

```
aws route53 create-hosted-zone --name ${MY_DOMAIN} --caller-reference ${MY_DOMAIN}
```

3. Use your domain registrar to change the nameservers for your zone (for example mylabs.dev) to use the Amazon Route 53 nameservers. Here is the way how you can find out the the Route 53 nameservers:

```
aws route53 get-hosted-zone --id $(aws route53 list-hosted-zones --query "HostedZones[?Name==\`${MY_DOMAIN}.\`].Id" --output text) --query "DelegationSet.NameServers"
```

4. Create policy allowing the cert-manager to change Route 53 settings. This will allow cert-manager to generate wildcard SSL certificates by Let's Encrypt certificate authority.
```
test -d tmp || mkdir tmp
envsubst < files/user_policy.json > tmp/user_policy.json
```
```
aws iam create-policy \
  --policy-name ${USER}-k8s-${MY_DOMAIN} \
  --description "Policy for ${USER}-k8s-${MY_DOMAIN}" \
  --policy-document file://tmp/user_policy.json \
| jq
```

Output: 
```
{
  "Policy": {
    "PolicyName": "dambor-k8s-gdambor.com",
    "PermissionsBoundaryUsageCount": 0,
    "CreateDate": "2020-04-12T16:00:27Z",
    "AttachmentCount": 0,
    "IsAttachable": true,
    "PolicyId": "ANPA6ASRE6HEVU2EZLUHG",
    "DefaultVersionId": "v1",
    "Path": "/",
    "Arn": "arn:aws:iam::963316609481:policy/dambor-k8s-gdambor.com",
    "UpdateDate": "2020-04-12T16:00:27Z"
  }
}
```

5. Create user which will use the policy above:
```
aws iam create-user --user-name ${USER}-k8s-${MY_DOMAIN} | jq && \
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName==\`${USER}-k8s-${MY_DOMAIN}\`].{ARN:Arn}" --output text) && \
aws iam attach-user-policy --user-name "${USER}-k8s-${MY_DOMAIN}" --policy-arn $POLICY_ARN && \
aws iam create-access-key --user-name ${USER}-k8s-${MY_DOMAIN} > $HOME/.aws/${USER}-k8s-${MY_DOMAIN} && \
export USER_AWS_ACCESS_KEY_ID=$(awk -F\" "/AccessKeyId/ { print \$4 }" $HOME/.aws/${USER}-k8s-${MY_DOMAIN}) && \
export USER_AWS_SECRET_ACCESS_KEY=$(awk -F\" "/SecretAccessKey/ { print \$4 }" $HOME/.aws/${USER}-k8s-${MY_DOMAIN})
```

Output

```
{
  "User": {
    "UserName": "dambor-k8s-gdambor.com",
    "Path": "/",
    "CreateDate": "2020-04-12T16:01:01Z",
    "UserId": "AIDA6ASRE6HETZXLHYIS5",
    "Arn": "arn:aws:iam::963316609481:user/dambor-k8s-gdambor.com"
  }
}
```

