# Configuring ArgoCD GitOps Pipeline

1. Clone this [GitOps Repo](https://github.com/dambor/gitops.git)

```
git clone https://github.com/dambor/gitops.git
```

2. Login to your ArgoCD install using the ArgoCD CLI and create a new pipeline:

```
argocd app create petclinic \
--repo https://github.com/<YOUR-REPO>/gitops.git \
--path petclinic-knative \
--dest-namespace default \
--dest-server https://kubernetes.default.svc \
--directory-recurse --sync-policy automated
```

![argocd-pipe](image.jpg)