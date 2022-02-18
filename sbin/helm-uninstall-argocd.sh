#!/bin/bash

DIRNAME=`dirname $0`

if [ -z ${ARGOCD_NS+x} ];then
  ARGOCD_NS='argocd'
fi

echo "INFO: Argocd will be uninstalled on $ARGOCD_NS namespace"
echo -n "Do you want to proceed? [y/n]: "
read ans
if [ "$ans" == "y" ]; then
  helm uninstall argocd --namespace=argocd
else
  echo "INFO: Exit without any action"
  exit 0
fi
