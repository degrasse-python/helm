#!/bin/bash

# Connect to cluster
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone us-central1-a --project $CLUSTER_PROJECT

# Add Helm repos
helm repo add stable https://charts.helm.sh/stable
helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
helm repo add kvaps https://kvaps.github.io/charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add sandbox-charts https://cb-sandbox.github.io/charts/
helm repo add jetstack https://charts.jetstack.io
helm repo add jfrog https://charts.jfrog.io
helm repo add oteemo-charts https://oteemo.github.io/charts
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts


# Update repos
helm repo update

# Installing Nginx ingress controller
if [ "$CD_ENABLED" = true ]; then
  helm upgrade --install ingress-nginx stable/nginx-ingress \
    -n ingress-nginx --create-namespace --version 1.25.0 \
    -f nginx/values.yaml
else
  helm upgrade --install ingress-nginx stable/nginx-ingress \
    -n ingress-nginx --create-namespace --version 1.25.0
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
    --set initAdminPassword.enabled=true \
    --set initAdminPassword.password="$NEXUS_TOKEN"
fi

if [ "$ARTIFACTORY_ENABLED" = true ]; then
  helm upgrade --install artifactory jfrog/artifactory-oss -n artifactory \
    --create-namespace -f artifactory/values.yaml --version "$ARTIFACTORY_VERSION" \
    --set artifactory.ingress.hosts[0]="artifactory.$BASE_DOMAIN" \
    --set artifactory.ingress.tls[0].hosts[0]="artifactory.$BASE_DOMAIN" \
    --set artifactory.admin.password="$ARTIFACTORY_TOKEN"
fi

if [ "$CI_ENABLED" = true ]; then
  CI_DOMAIN="sda.$BASE_DOMAIN"
  CI_NAMESPACE="cloudbees-sda"
  helm upgrade --install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver -n kube-system
  kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/main/deploy/provider-gcp-plugin.yaml

  kubectl create ns $CI_NAMESPACE
  kubectl create secret generic ci-pass --from-literal=password="$CI_ADMIN_PASS" --dry-run=client -o yaml | kubectl apply -n $CI_NAMESPACE -f -
  kubectl -n $CI_NAMESPACE create configmap cbci-oc-init-groovy --from-file=ci/groovy-init/ --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n $CI_NAMESPACE create configmap cbci-oc-quickstart-groovy --from-file=ci/groovy-quickstart/ --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n $CI_NAMESPACE create configmap cbci-op-casc-bundle --from-file=ci/ops-config-bundle/ --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n $CI_NAMESPACE apply -f ci/k8s/role.yaml

  helm upgrade --install cloudbees-ci cloudbees/cloudbees-core -n "$CI_NAMESPACE" \
    --create-namespace -f ci/values.yaml --version "$CI_VERSION" \
    --set OperationsCenter.HostName="$CI_DOMAIN" \
    $(if [ "$CD_ENABLED" = true ]; then echo "--set sda=true"; fi) \
    --set-file 'OperationsCenter.ExtraGroovyConfiguration.z-quickstart-hook\.groovy'=./ci/groovy-license-activated/z-quickstart-hook.groovy
  . ./scripts/workload_identity.sh
fi


if [ "$CD_ENABLED" = true ]; then
  CD_DOMAIN="sda.$BASE_DOMAIN"
  CD_NAMESPACE="cloudbees-sda"
  export CD_LICENSE=$(cat $CD_LICENSE)
  # Install SSD storage class
  kubectl apply -f ./k8s/ssd.yaml
  # Install nfs-server-provisioner
  helm upgrade --install nfs-server-provisioner kvaps/nfs-server-provisioner --version 1.1.1 \
    -n "$CD_NAMESPACE" --create-namespace -f nfs-server-provisioner/values.yaml
  # Install mysql
  helm upgrade --install mysql sandbox-charts/mysql \
    -n "$CD_NAMESPACE" --create-namespace -f mysql/values.yaml \
    --set mysqlPassword=$MYSQL_PASSWORD \
    --set mysqlRootPassword=$MYSQL_PASSWORD
  # Install CD
  kubectl apply -f ./k8s/cdAgentRole.yaml
  kubectl apply -f ./k8s/cdAgentRoleBinding.yaml

  helm upgrade --install cloudbees-cd cloudbees/cloudbees-flow -n "$CD_NAMESPACE" \
    --create-namespace -f cd/values.yaml --version "$CD_VERSION" \
    --set ingress.host="$CD_DOMAIN" $(if [ "$CD_IMAGE_TAG" ]; then echo "--set images.tag=$CD_IMAGE_TAG"; fi) \
    --set externalGatewayAgent.service.publicHostName="$CD_DOMAIN" \
    --set flowCredentials.adminPassword=$CD_ADMIN_PASS \
    --set database.dbPassword=$MYSQL_PASSWORD \
    --set flowLicense.licenseData="$CD_LICENSE" \
    --set serverName="$CD_DOMAIN" \
    --set repository.serviceEndpoint="$CD_DOMAIN" \
    --timeout 10000s
  # Install CD agent
  helm upgrade --install agent cloudbees/cloudbees-flow-agent \
    -f cd/agent/values.yaml -n "$CD_NAMESPACE" \
    --set flowCredentials.password=$CD_ADMIN_PASS \
    --wait
fi
