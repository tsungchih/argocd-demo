# argocd-demo

## Installation

We may install the Argo CD by means of the shell script under `sbin` directory.

```shell
$ git clone https://github.com/tsungchih/argocd-demo.git
$ cd argocd-demo
$ sbin/helm-install-argocd.sh helm/argo-cd/values-non-ha.yaml
```
## Image Updater

To demonstrate Argo CD Image Updater, we created an ApplicationSet to install Sealed-secrets 
to all the Kubernetes clusters, see `applications/sealed-secrets/applicationset.yaml`. The 
template in the `ApplicationSet` includes the following annotations:

```
argocd-image-updater.argoproj.io/image-list: sealed-secrets=quay.io/bitnami/sealed-secrets-controller
argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/github-creds
argocd-image-updater.argoproj.io/git-branch: master
argocd-image-updater.argoproj.io/sealed-secrets.allow-tags: regexp:^[vV]*([0-9]+)\.([0-9]+)\.([0-9]+)$
argocd-image-updater.argoproj.io/sealed-secrets.update-strategy: latest
argocd-image-updater.argoproj.io/sealed-secrets.helm.image-name: sealed-secrets.image.name
argocd-image-updater.argoproj.io/sealed-secrets.helm.image-tag: sealed-secrets.image.tag
```

The `write-back-method` shows that image updater should write image tag back to a git repository and the 
authentication information could be referenced from a `Secret` called `github-creds` in `argocd` namespace. 
To make it work, you have to use the following command to create your own `Secret` in `argocd` namespace 
with proper authentication information.

```shell
$ kubectl -n argocd create secret generic github-creds \
    --from-literal=username=<USERNAME> \
    --from-literal=password=<PAT>
```

After having created all the above resources in your Kubernetes cluster, you may see a new file 
(`argocd-demo/helm/sealed-secrets/.argocd-source-in-cluster-bitnami-sealed-secrets.yaml`) got pushed 
into the `master` branch with the follwing similar content.

```
helm:
  parameters:
  - name: sealed-secrets.image.name
    value: quay.io/bitnami/sealed-secrets-controller
    forcestring: true
  - name: sealed-secrets.image.tag
    value: v0.17.3
    forcestring: true
```
