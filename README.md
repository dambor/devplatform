# Dev Platform

## What we're building

In this tutorial we'll build a dev platform for learning purposes, leveraging KPack, ArgoCD and Knative deployed on top of a Kubernetes Cluster version 1.17 provided by Tanzu Kubernetes Grid (TKG) created and managed by Tanzu Mission Control (TMC). And for now we're using external tools such as Github and DockerHub.

Below a picture of what we're going to implement:

![petclinic](https://github.com/dambor/devplatform/blob/master/png/architecture.jpg)

## Initial Consideration

* Before we get started, clone this repo to your workspace.
* In order to have a reliable and reproducible tutorial the original projects scripts were saved on this repo so it doesn't get affected by global changes.


## Deploying the Technology Stack

* [Create a cluster using TMC CLI](https://github.com/dambor/devplatform/blob/master/tmc-tutorial.md)
* [Install knative](https://github.com/dambor/devplatform/blob/master/knative-tutorial.md)
* [Install kpack](https://github.com/dambor/devplatform/blob/master/kpack-tutorial.md)
* [Install ArgoCD](https://github.com/dambor/devplatform/blob/master/argocd-tutorial.md)

## Configuring DevOps Environment

* [Deploy an Image](https://github.com/dambor/devplatform/blob/master/deploy-image.md)
* [Configuring ArgoCD GitOps Pipeline]()

## References

* [KPack](https://github.com/pivotal/kpack)
* [KNative](https://knative.dev/docs/)
* [ArgoCD](https://github.com/argoproj/argo-cd)

## Roadmap

For the next release, we'll be including

* Harbor Registry for Docker Images repository
* Include Tekton for implementing a full Continuous Integration