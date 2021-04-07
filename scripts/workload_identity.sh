#!/bin/bash

echo "----> Setting up Workload Identity"

GCP_SA_NAME=jenkins-build-sa
NAMESPACE=cloudbees-sda
K8S_SA_NAME=jenkins

gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$CLUSTER_PROJECT.svc.id.goog[$NAMESPACE/$K8S_SA_NAME]" \
  $GCP_SA_NAME@$CLUSTER_PROJECT.iam.gserviceaccount.com

kubectl annotate serviceaccount -n $NAMESPACE $K8S_SA_NAME \
  iam.gke.io/gcp-service-account=$GCP_SA_NAME@$CLUSTER_PROJECT.iam.gserviceaccount.com
