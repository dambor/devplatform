# Install GitLab

1. Add GitLab repository:

```
helm repo add gitlab https://charts.gitlab.io/
helm repo update
```

2. Create gitlab namespaces with secrets needed for GitLab (certificates and passwords):

First make sure you have converted the certificate to `pem` format

```
openssl x509 -in /tmp/kube/ca.crt -out /tmp/kube/ca.pem
```

Then run the following commands:

```
kubectl create namespace gitlab
kubectl create secret generic gitlab-initial-root-password --from-literal=password="admin123" -n gitlab
kubectl create secret generic custom-ca --from-file=unique_name=/tmp/kube/ca.pem -n gitlab
```

3. Create Istio Gateways and VirtualServices to allow accessing GitLab from "outside":

```
cat << EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: gitlab-gateway
  namespace: gitlab
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 22
      name: ssh-gitlab
      protocol: TCP
    hosts:
    - gitlab.${MY_DOMAIN}
  - port:
      number: 80
      name: http-gitlab
      protocol: HTTP
    hosts:
    - gitlab.${MY_DOMAIN}
    - minio.${MY_DOMAIN}
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https-gitlab
      protocol: HTTPS
    hosts:
    - gitlab.${MY_DOMAIN}
    - minio.${MY_DOMAIN}
    tls:
      credentialName: ingress-cert-${LETSENCRYPT_ENVIRONMENT}
      mode: SIMPLE
      privateKey: sds
      serverCertificate: sds
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: gitlab-ssh-virtual-service
  namespace: gitlab
spec:
  hosts:
  - gitlab.${MY_DOMAIN}
  gateways:
  - gitlab-gateway
  tcp:
  - match:
    - port: 22
    route:
    - destination:
        host: gitlab-gitlab-shell.gitlab.svc.cluster.local
        port:
          number: 22
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: gitlab-http-virtual-service
  namespace: gitlab
spec:
  hosts:
  - gitlab.${MY_DOMAIN}
  gateways:
  - gitlab-gateway
  http:
  - match:
    - uri:
        prefix: /admin/sidekiq
    route:
    - destination:
        host: gitlab-unicorn.gitlab.svc.cluster.local
        port:
          number: 8080
  - route:
    - destination:
        host: gitlab-unicorn.gitlab.svc.cluster.local
        port:
          number: 8181
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: gitlab-minio-virtual-service
  namespace: gitlab
spec:
  hosts:
  - minio.${MY_DOMAIN}
  gateways:
  - gitlab-gateway
  http:
  - route:
    - destination:
        host: gitlab-minio-svc.gitlab.svc.cluster.local
        port:
          number: 9000
EOF
```

4. Install GitLab using Helm (make sure to run this command on bash):

```
helm install gitlab gitlab/gitlab --namespace gitlab --wait \
  --set certmanager.install=false \
  --set gitlab-runner.install=false \
  --set gitlab.gitaly.persistence.size=1Gi \
  --set gitlab.unicorn.ingress.enabled=false \
  --set global.appConfig.cron_jobs.ci_archive_traces_cron_worker.cron="17 * * * *" \
  --set global.appConfig.cron_jobs.expire_build_artifacts_worker.cron="50 * * * *" \
  --set global.appConfig.cron_jobs.pipeline_schedule_worker.cron="19 * * * *" \
  --set global.appConfig.cron_jobs.repository_archive_cache_worker.cron="0 * * * *" \
  --set global.appConfig.cron_jobs.repository_check_worker.cron="20 * * * *" \
  --set global.appConfig.cron_jobs.stuck_ci_jobs_worker.cron="0 * * * *" \
  --set global.appConfig.gravatar.plainUrl="https://www.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon" \
  --set global.appConfig.gravatar.sslUrl="https://secure.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon" \
  --set global.certificates.customCAs[0].secret=custom-ca \
  --set global.edition=ce \
  --set global.hosts.domain=${MY_DOMAIN} \
  --set global.ingress.configureCertmanager=false \
  --set global.ingress.enabled=false \
  --set global.initialRootPassword.secret=gitlab-initial-root-password \
  --set minio.persistence.size=5Gi \
  --set nginx-ingress.enabled=false \
  --set postgresql.persistence.size=1Gi \
  --set prometheus.install=false \
  --set redis.persistence.size=1Gi \
  --set registry.enabled=false
```

Output:

```
NAME: gitlab
LAST DEPLOYED: Tue Apr 14 09:33:37 2020
NAMESPACE: gitlab
STATUS: deployed
REVISION: 1
NOTES:
WARNING: Automatic TLS certificate generation with cert-manager is disabled and no TLS certificates were provided. Self-signed certificates were generated.

You may retrieve the CA root for these certificates from the `gitlab-wildcard-tls-ca` secret, via the following command. It can then be imported to a web browser or system store.

    kubectl get secret gitlab-wildcard-tls-ca -ojsonpath='{.data.cfssl_ca}' | base64 --decode > gitlab.gdambor.com.ca.pem

If you do not wish to use self-signed certificates, please set the following properties:
  - global.ingress.tls.secretName
  OR
  - global.ingress.tls.enabled (set to `true`)
  - gitlab.unicorn.ingress.tls.secretName
  - minio.ingress.tls.secretName
```

5. Try to access the GitLab using the URL https://gitlab.${MY_DOMAIN} with following credentials:

```
Username: root
Password: admin123
```

6. Create Personal Access Token 1234567890 for user root:

```
UNICORN_POD=$(kubectl get pods -n gitlab -l=app=unicorn -o jsonpath="{.items[0].metadata.name}")
echo ${UNICORN_POD}
kubectl exec -n gitlab -it $UNICORN_POD -c unicorn -- /bin/bash -c "
cd /srv/gitlab;
bin/rails r \"
token_digest = Gitlab::CryptoHelper.sha256 \\\"1234567890\\\";
token=PersonalAccessToken.create!(name: \\\"Full Access\\\", scopes: [:api], user: User.where(id: 1).first, token_digest: token_digest);
token.save!
\";
"
```

Output:

```
gitlab-unicorn-cd8585b7d-cxnht
```

7. Create new user myuser:

```
GITLAB_USER_ID=$(curl -s -k -X POST -H "Content-type: application/json" -H "PRIVATE-TOKEN: 1234567890" https://gitlab.${MY_DOMAIN}/api/v4/users -d \
"{
  \"name\": \"myuser\",
  \"username\": \"myuser\",
  \"password\": \"myuser_password\",
  \"email\": \"myuser@${MY_DOMAIN}\",
  \"skip_confirmation\": true
}" | jq ".id")
echo ${GITLAB_USER_ID}
```

Output:

```
2
```

8. Create a personal access token for user myuser:

```
kubectl exec -n gitlab -it $UNICORN_POD -c unicorn -- /bin/bash -c "
cd /srv/gitlab;
bin/rails r \"
token_digest = Gitlab::CryptoHelper.sha256 \\\"0987654321\\\";
token=PersonalAccessToken.create!(name: \\\"Full Access\\\", scopes: [:api], user: User.where(id: ${GITLAB_USER_ID}).first, token_digest: token_digest);
token.save!
\";
"
```

9. Create Impersonation token for myuser:

```
GILAB_MYUSER_TOKEN=$(curl -s -k -X POST -H "Content-type: application/json" -H "PRIVATE-TOKEN: 1234567890" https://gitlab.${MY_DOMAIN}/api/v4/users/${GITLAB_USER_ID}/impersonation_tokens -d \
"{
  \"name\": \"mytoken\",
  \"scopes\": [\"api\"]
}" | jq -r ".token")
echo ${GILAB_MYUSER_TOKEN}
```

Output:

```
fTsvqN4JFtjyh9QT8Lvq
```

10. Create SSH key which will be imported to GitLab:

```
ssh-keygen -t ed25519 -f /tmp/id_rsa_gitlab -q -N "" -C "ssh_key@gdambor.com"
```

11. Add ssh key to the myuser:
```
curl -sk -X POST -F "private_token=${GILAB_MYUSER_TOKEN}" https://gitlab.${MY_DOMAIN}/api/v4/user/keys -F "title=ssh_key" -F "key=$(cat /tmp/id_rsa_gitlab.pub)" | jq
```

Output:

```
{
  "id": 1,
  "title": "ssh_key",
  "key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINI/hdLuO/OCtBJ8yL8+qC8iYqYrF2lyZXQvp8uF+M1g ssh_key@gdambor.com",
  "created_at": "2020-04-14T14:46:17.479Z",
  "expires_at": null
}
```

12. Create new project:

```
PROJECT_ID=$(curl -s -k -X POST -H "Content-type: application/json" -H "PRIVATE-TOKEN: 1234567890" https://gitlab.${MY_DOMAIN}/api/v4/projects/user/${GITLAB_USER_ID} -d \
"{
  \"user_id\": \"${GITLAB_USER_ID}\",
  \"name\": \"petclinic\",
  \"description\": \"Spring PetClinic\",
  \"wiki_access_level\": \"disabled\",
  \"issues_access_level\": \"disabled\",
  \"builds_access_level\": \"disabled\",
  \"snippets_access_level\": \"disabled\",
  \"container-registry-enabled\": false,
  \"visibility\": \"public\"
}" | jq -r ".id")
echo ${PROJECT_ID}
```

Output:
```
1
```

13. Clone the podinfo project (https://github.com/dambor/spring-petclinic) and push it to the newly created git repository my-podinfo:

```
export GIT_SSH_COMMAND="ssh -i /tmp/id_rsa_gitlab -o UserKnownHostsFile=/dev/null"
git clone --bare https://github.com/dambor/spring-petclinic /tmp/spring-petclinic
git -C /tmp/spring-petclinic push --mirror git@gitlab.${MY_DOMAIN}:myuser/petclinic.git
rm -rf /tmp/spring-petclinic
```

Output:

```
Cloning into bare repository '/tmp/podinfo'...
remote: Enumerating objects: 100, done.
remote: Counting objects: 100% (100/100), done.
remote: Compressing objects: 100% (77/77), done.
remote: Total 5438 (delta 33), reused 64 (delta 19), pack-reused 5338
Receiving objects: 100% (5438/5438), 9.61 MiB | 6.61 MiB/s, done.
Resolving deltas: 100% (2422/2422), done.
The authenticity of host 'gitlab.gdambor.com (3.211.32.34)' can't be established.
ECDSA key fingerprint is SHA256:gOCki5ugoy9IuemqkmMdGPcbKCq5zO0nt2KiQ/9tAB4.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'gitlab.gdambor.com,3.211.32.34' (ECDSA) to the list of known hosts.
Enumerating objects: 5438, done.
Counting objects: 100% (5438/5438), done.
Delta compression using up to 8 threads
Compressing objects: 100% (2628/2628), done.
Writing objects: 100% (5438/5438), 9.61 MiB | 13.27 MiB/s, done.
Total 5438 (delta 2422), reused 5438 (delta 2422)
remote: Resolving deltas: 100% (2422/2422), done.
remote:
remote: To create a merge request for gh-pages, visit:
remote:   https://gitlab.gdambor.com/myuser/my-podinfo/-/merge_requests/new?merge_request%5Bsource_branch%5D=gh-pages
remote:
remote: To create a merge request for v0.x, visit:
remote:   https://gitlab.gdambor.com/myuser/my-podinfo/-/merge_requests/new?merge_request%5Bsource_branch%5D=v0.x
remote:
remote: To create a merge request for v1.x, visit:
remote:   https://gitlab.gdambor.com/myuser/my-podinfo/-/merge_requests/new?merge_request%5Bsource_branch%5D=v1.x
remote:
remote: To create a merge request for v3.x, visit:
remote:   https://gitlab.gdambor.com/myuser/my-podinfo/-/merge_requests/new?merge_request%5Bsource_branch%5D=v3.x
remote:
To gitlab.gdambor.com:myuser/my-podinfo.git
 * [new branch]      gh-pages -> gh-pages
 * [new branch]      master -> master
 * [new branch]      v0.x -> v0.x
 * [new branch]      v1.x -> v1.x
 * [new branch]      v3.x -> v3.x
 * [new tag]         0.2.2 -> 0.2.2
 * [new tag]         2.0.0 -> 2.0.0
 * [new tag]         2.0.1 -> 2.0.1
 * [new tag]         2.0.2 -> 2.0.2
 * [new tag]         2.1.0 -> 2.1.0
 * [new tag]         2.1.1 -> 2.1.1
 * [new tag]         2.1.2 -> 2.1.2
 * [new tag]         2.1.3 -> 2.1.3
 * [new tag]         3.0.0 -> 3.0.0
 * [new tag]         3.1.0 -> 3.1.0
 * [new tag]         3.1.1 -> 3.1.1
 * [new tag]         3.1.2 -> 3.1.2
 * [new tag]         3.1.3 -> 3.1.3
 * [new tag]         3.1.4 -> 3.1.4
 * [new tag]         3.1.5 -> 3.1.5
 * [new tag]         3.2.0 -> 3.2.0
 * [new tag]         3.2.1 -> 3.2.1
 * [new tag]         3.2.2 -> 3.2.2
 * [new tag]         flux-floral-pine-16 -> flux-floral-pine-16
 * [new tag]         flux-thawing-star-34 -> flux-thawing-star-34
 * [new tag]         v0.4.0 -> v0.4.0
 * [new tag]         v0.5.0 -> v0.5.0
 * [new tag]         v1.0.0 -> v1.0.0
 * [new tag]         v1.1.0 -> v1.1.0
 * [new tag]         v1.1.1 -> v1.1.1
 * [new tag]         v1.2.0 -> v1.2.0
 * [new tag]         v1.2.1 -> v1.2.1
 * [new tag]         v1.3.0 -> v1.3.0
 * [new tag]         v1.3.1 -> v1.3.1
 * [new tag]         v1.4.0 -> v1.4.0
 * [new tag]         v1.4.1 -> v1.4.1
 * [new tag]         v1.4.2 -> v1.4.2
 * [new tag]         v1.6.0 -> v1.6.0
 * [new tag]         v1.7.0 -> v1.7.0
 * [new tag]         v1.8.0 -> v1.8.0
```

