#!/bin/bash

DIRNAME=`dirname $0`
ENV="${1:-argo-workflows}"
ENVDIR="${DIRNAME}/../kustomize/${ENV}"
BASEDIR="${DIRNAME}/../kustomize/${ENV}/base"

if [ ! -d ${ENVDIR} ]; then
  echo "Error: ${ENVDIR} not found. The installation can not continue."
  exit 0
fi

echo "INFO: Argo Workflows will be installed within argo namespace."
echo -n "Do you want to proceed? [y/n]: "
read ans
if [ "$ans" == "y" ]; then
  kubectl kustomize ${ENVDIR} | kubectl apply -f -
else
  echo "INFO: Exit without any action"
  exit 0
fi
