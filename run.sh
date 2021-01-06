#!/bin/bash

# Connect to cluster
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone us-central1-a --project $CLUSTER_PROJECT

# Add Helm repos
helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
helm repo add kvaps https://kvaps.github.io/charts
helm repo add sandbox-charts https://cb-sandbox.github.io/charts/
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add jfrog https://charts.jfrog.io
helm repo add oteemo-charts https://oteemo.github.io/charts


# Update repos
helm repo update


# Installing Nginx ingress controller
if [ "$CD_ENABLED" = true ]; then
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    -n ingress-nginx --create-namespace \
    -f nginx/values.yaml
else
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    -n ingress-nginx --create-namespace
fi

# Setup DNS
. ./scripts/dns.sh


# Install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --set installCRDs=true -n cert-manager --create-namespace
sleep 45
sed "s/REPLACE_EMAIL/$EMAIL/g" cert-manager/issuers.yaml | kubectl apply -f -


if [ "$SONARQUBE_ENABLED" = true ]; then
  helm upgrade --install sonarqube oteemo-charts/sonarqube -n sonarqube \
  --create-namespace -f sonarqube/values.yaml --version "$SONARQUBE_VERSION" \
  --set ingress.hosts[0].name="sonar.$BASE_DOMAIN" \
  --set ingress.tls[0].hosts[0]="sonar.$BASE_DOMAIN" \
  --set account.adminPassword="$SONARQUBE_TOKEN"
fi

if [ "$NEXUS_ENABLED" = true ]; then
  helm upgrade --install nexus oteemo-charts/sonatype-nexus -n nexus \
  --create-namespace -f nexus/values.yaml --version "$NEXUS_VERSION" \
  --set nexusProxy.env.nexusHttpHost="nexus.$BASE_DOMAIN" \
  --set nexusProxy.env.nexusDockerHost="docker.$BASE_DOMAIN" \
  --set initAdminPassword.password="$NEXUS_TOKEN"
fi

if [ "$ARTIFACTORY_ENABLED" = true ]; then
  helm upgrade --install artifactory jfrog/artifactory-oss -n artifactory \
  --create-namespace -f artifactory/values.yaml --version "$ARTIFACTORY_VERSION" \
  --set artifactory.ingress.hosts[0]="artifactory.$BASE_DOMAIN" \
  --set artifactory.ingress.tls[0].hosts[0]="artifactory.$BASE_DOMAIN" \
  --set account.adminPassword="$ARTIFACTORY_TOKEN"
fi


if [ "$CI_ENABLED" = true ]; then
  helm upgrade --install cloudbees-ci cloudbees/cloudbees-core -n cloudbees-ci \
    --create-namespace -f ci/values.yaml --version "$CI_VERSION" \
    --set OperationsCenter.HostName="ci.$BASE_DOMAIN"
fi

if [ "$CD_ENABLED" = true ]; then
  export CD_LICENSE=$(cat $CD_LICENSE)
  # Install SSD storage class
  kubectl apply -f ./k8s/ssd.yaml
  # Install nfs-server-provisioner
  helm upgrade --install nfs-server-provisioner kvaps/nfs-server-provisioner --version 1.1.1 \
    -n cloudbees-cd --create-namespace -f nfs-server-provisioner/values.yaml
  # Install mysql
  helm upgrade --install mysql sandbox-charts/mysql \
    -n cloudbees-cd --create-namespace -f mysql/values.yaml \
    --set mysqlPassword=$MYSQL_PASSWORD \
    --set mysqlRootPassword=$MYSQL_PASSWORD
  # Install CD
  helm upgrade --install cloudbees-cd cloudbees/cloudbees-flow -n cloudbees-cd \
    --create-namespace -f cd/values.yaml --version "$CD_VERSION" \
    --set ingress.host="cd.$BASE_DOMAIN" \
    --set flowCredentials.adminPassword=$CD_ADMIN_PASS \
    --set database.dbPassword=$MYSQL_PASSWORD \
    --set flowLicense.licenseData="$CD_LICENSE" \
    --timeout 10000s
  # Install CD agent
  helm upgrade --install agent cloudbees/cloudbees-flow-agent \
    -f cd/agent/values.yaml -n cloudbees-cd \
    --set flowCredentials.password=$CD_ADMIN_PASS
fi
