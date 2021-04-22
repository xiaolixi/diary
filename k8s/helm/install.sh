#!/bin/bash
set -xeu
set -o pipefail
 
kubectl create -f  `ls *.yaml`
helm init --service-account tiller --tiller-image ${imageTag} --skip-refresh
echo ""
echo ""
echo ""
echo ""
echo ""
 
helm version
