#!/bin/bash

DIRNAME=`dirname $0`
ENV="${1:-non-ha}"
VER="${2:-v2.2.5}"
ENVDIR="${DIRNAME}/../kustomize/${ENV}"
BASEDIR="${DIRNAME}/../kustomize/${ENV}/base"

if [ ! -d ${ENVDIR} ]; then
  echo "Error: ${ENVDIR} not found. The installation can not continue."
  exit 0
elif [ ! -f ${BASEDIR}/argocd-${VER}-namespace-install.yaml ]; then
  echo "Error: argocd-${VER}-namespace-install.yaml not found in the corresponding base dir."
  echo "Please check if the version is correct."
  exit 0
fi

echo "INFO: Argocd will be installed within argocd namespace."
echo -n "Do you want to proceed? [y/n]: "
read ans
if [ "$ans" == "y" ]; then
  kubectl apply -f ${BASEDIR}/argocd-${VER}-namespace-install.yaml
  kustomize build ${ENVDIR} | kubectl apply -f -
else
  echo "INFO: Exit without any action"
  exit 0
fi
