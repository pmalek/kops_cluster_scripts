#!/bin/bash

set -x

# source .env

helm upgrade \
  -f ./values_long.yaml \
  --install my-release \
  "${HOME}/code/sumologic-kubernetes-collection/deploy/helm/sumologic/"

# --set sumologic.accessId=${SUMO_ACCESS_ID} \
# --set sumologic.accessKey=${SUMO_ACCESS_KEY} \
# --set sumologic.clusterName=${DOMAIN}

