# argocd-demo

The [argocd-demo](https://github.com/tsungchih/argocd-demo) is aimed 
at demonstrting the use of Argo CD for the platform team to implement GitOps.

## Repo Structure

This repo is initially organized as follows.

```shell
argocd-demo
├── helm
│   ├── ...
│   └── argo-cd
│       └── charts
├── projects
├── applications
└── sbin
```

The `sbin` directory includes all the shell binaries. The `helm` directory 
contains Helm charts when we have source code and deployment manifests 
separated. We put a Helm chart with respect to Argo CD in `helm` directory 
with the following dependencies: Argo CD Image Updater, Argo CD 
ApplicationSet Controller, Argo CD Notifications, Argo CD Rollouts. The 
`projects` directory includes all the manifests as to Argo CD Projects. 
To create a new Argo CD Project, we can commit the corresponding manifest 
file in `projects` directory. The `applications` directory embraces all the 
manifests as to Argo CD Application. To create a new Argo CD Application, we 
can commit the corresponding manifest file in `applications` directory.

## Installation

We may install the Argo CD by means of the shell script under `sbin` 
directory. Here is an example to install Argo CD with non-ha mode.

```shell
$ git clone https://github.com/tsungchih/argocd-demo.git
$ cd argocd-demo
$ sbin/helm-install-argocd.sh helm/argo-cd/values-non-ha.yaml
```

Once the installation has been finished, we can use the following command 
to retrieve the default password for `admin` user to login.

```shell
$ kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

To start using Argo CD via its web UI, we may use the following command to 
use port-forwarding for connecting to the API server without exposing the 
service.

```shell
$ kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open the browser and visit `https://localhost:8080` to login Argo CD.

## Configuration Management

When installing Argo CD by means of Helm chart, we can manage its related 
configurations via helm values file, such as `values-non-ha.yaml` located 
in `helm/argo-cd/`. Interested readers are referred to the 
[argo-helm](https://github.com/argoproj/argo-helm) website for more detail 
of each Helm dependency mentioned in the previous section. As an example, we 
will describe how to add a new directory for Argo CD to manage.

Suppose that we want Argo CD to manage `projects` directory so that all the 
changes could be automatically applied to the designated destination. We can 
create an Argo CD Application resource. Its corresponding configurations could 
be added to `argocd.server.additionalApplications` section in 
`helm/argo-cd/values-non-ha.yaml` as follows.

```yaml
argo-cd:
  server:
    additionalApplications:
      - name: argocd-appprojects
        namespace: argocd
        destination:
          namespace: argocd
          server: https://kubernetes.default.svc
        project: argocd
        source:
          path: projects
          repoURL: https://github.com/tsungchih/argocd-demo.git
          targetRevision: HEAD
          directory:
            recurse: true
            jsonnet: {}
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
            allowEmpty: false
          syncOptions:
          - Validate=true
          - CreateNamespace=true
          - PrunePropagationPolicy=foreground
          - PruneLast=true
```

The above configuration snippets tells the Argo CD to create an additional 
`Application` resource immediately after the Argo CD has finished 
installation. The name of this `Application` resource is `argocd-appprojects`. 
The deployment manifests source comes from the `path` in the specified 
`repoURL`. And they will be applied to the specified destination and 
namespace.

As of now, we can create a new Argo CD Project by dropping the corresponding 
`AppProject` YAML file in `projects` directory. A simple example to create 
an `infrastructure` project is listed as follows.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: infrastructure
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: Infrastructure applications.
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  orphanedResources:
    warn: false
```

The `spec` says that the there has no restriction to the source repository 
and the destination attached to all the Argo CD Applications within 
`infrastructure` project.

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
