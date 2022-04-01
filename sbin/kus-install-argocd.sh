#!/bin/bash

DIRNAME=`dirname $0`
ENV="${1:-non-ha}"
ENVDIR="${DIRNAME}/../kustomize/${ENV}"
BASEDIR="${DIRNAME}/../kustomize/${ENV}/base"

if [ ! -d ${ENVDIR} ]; then
  echo "Error: ${ENVDIR} not found. The installation can not continue."
  exit 0
fi

echo "INFO: Argocd will be installed within argocd namespace."
echo -n "Do you want to proceed? [y/n]: "
read ans
if [ "$ans" == "y" ]; then
  kubectl kustomize ${ENVDIR} | kubectl apply -f -
else
  echo "INFO: Exit without any action"
  exit 0
fi
