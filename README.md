# argo-demo

The [argo-demo](https://gitlab.bigdatainn-prd.site/devops/argo-demo) is aimed 
at demonstrting the use of Argo CD for the platform team to implement GitOps.

## Repo Structure

This repo is initially organized as follows.

```shell
argo-demo
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
$ git clone https://gitlab.bigdatainn-prd.site/devops/argo-demo.git
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
          repoURL: https://gitlab.bigdatainn-prd.site/devops/argo-demo.git
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

## Clusters

Clusters in Argo CD is represented as Secrets with mandatory label: `argocd.argoproj.io/secret-type: cluster`. 
The corresponding secret data could be found [here](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters). In this section, we're going to demonstrate how to add a GKE cluster.

First of all, we apply the following manifests to the GKE cluster which is going to be added to the Argo CD.

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: argocd
  namespace: kube-system
```

We can then get the corresponding secret name by means of the following command.

```shell
$ kubectl -n kube-system get sa argocd -o json | jq -r '.secrets[0].name'
argocd-token-qncfd
```

Note that the secret name shown above is `argocd-token-qncfd`. Subsequently, 
we get the `token` and the `ca.crt` data from within the secret. We have to 
decode the token we got from the `argocd-token-qncfd` since it is encoded by 
base64.

```shell
$ kubectl -n kube-system get secrets argocd-token-qncfd -o json | jq -r '.data.token' | base64 -d
```

The `caData` in cluster secret could be required as follows.

```shell
$ kubectl -n kube-system get secrets argocd-token-qncfd -o json | jq -r '.data."ca.crt"'
```

We may put the above three commands all together in a shell script.

```shell
#!/bin/bash

secret=$(kubectl -n kube-system get sa argocd -o json | jq -r '.secrets[0].name')
echo "token:"
kubectl -n kube-system get secrets $secret -o json | jq -r '.data.token' | base64 -d
echo
echo "ca.crt:"
kubectl -n kube-system get secrets $secret -o json | jq -r '.data."ca.crt"'
```

We can then generate the cluster secret as follows.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: brand-new-cluster-secret
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: brand-new-cluster
  server: https://brand-new-cluster.example.com
  config: |
    {
      "bearerToken": "<token>", # this is the token, it cannot be base64
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<ca.crt>" # this has to be base64 encoded
      }
    }
```

Now we encrypt the cluster secret by means of sealed-secrets.

```shell
$ kubeseal --namespace=argocd --scope=namespace-wide --cert=keys/in-cluster-sealed-secrets.pem --secret-file=<path-to-secret> --format=yaml > clusters/dev-sealed.yaml
```

## Image Updater

To demonstrate Argo CD Image Updater, we created an ApplicationSet to install Sealed-secrets 
to all the Kubernetes clusters, see `applications/sealed-secrets/applicationset.yaml`. The 
template in the `ApplicationSet` includes the following annotations:

```
argocd-image-updater.argoproj.io/image-list: sealed-secrets=quay.io/bitnami/sealed-secrets-controller
argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/gitlab-creds
argocd-image-updater.argoproj.io/git-branch: master
argocd-image-updater.argoproj.io/sealed-secrets.allow-tags: regexp:^[vV]*([0-9]+)\.([0-9]+)\.([0-9]+)$
argocd-image-updater.argoproj.io/sealed-secrets.update-strategy: latest
argocd-image-updater.argoproj.io/sealed-secrets.helm.image-name: sealed-secrets.image.name
argocd-image-updater.argoproj.io/sealed-secrets.helm.image-tag: sealed-secrets.image.tag
```

The `write-back-method` shows that image updater should write image tag back to a git repository and the 
authentication information could be referenced from a `Secret` called `gitlab-creds` in `argocd` namespace. 
To make it work, you have to use the following command to create your own `Secret` in `argocd` namespace 
with proper authentication information.

```shell
$ kubectl -n argocd create secret generic gitlab-creds \
    --from-literal=username=<USERNAME> \
    --from-literal=password=<PAT>
```

After having created all the above resources in your Kubernetes cluster, you may see a new file 
(`argocd-demo/helm/sealed-secrets/.argocd-source-in-cluster-bitnami-sealed-secrets.yaml`) got pushed 
into the `master` branch with the follwing similar content.

```yaml
helm:
  parameters:
  - name: sealed-secrets.image.name
    value: quay.io/bitnami/sealed-secrets-controller
    forcestring: true
  - name: sealed-secrets.image.tag
    value: v0.17.3
    forcestring: true
```
