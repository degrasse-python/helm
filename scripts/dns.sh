echo '----> Setting up DNS records'

rm -f transaction.yaml
INGRESS_IP=$(kubectl get -n ingress-nginx svc | grep ingress-nginx-nginx-ingress-controller | head -n 1 | awk '{print $4}')

while [[ ! $INGRESS_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
do
  sleep 5
  echo "waiting 5"
  INGRESS_IP=$(kubectl get -n ingress-nginx svc | grep ingress-nginx-nginx-ingress-controller | head -n 1 | awk '{print $4}')
done

gcloud config set project $DNS_PROJECT

# Grab the current IP address of the DNS record
OLD_IP=$(gcloud dns record-sets list --zone=$DNS_ZONE | grep *.$BASE_DOMAIN | awk '{print $4}')
CURRENT_TTL=$(gcloud dns record-sets list --zone=$DNS_ZONE | grep *.$BASE_DOMAIN | awk '{print $3}')


# Start the transaction
gcloud dns record-sets transaction start --zone=$DNS_ZONE
if [[ $OLD_IP ]]; then
  gcloud dns record-sets transaction remove $OLD_IP --name=*.$BASE_DOMAIN \
  --ttl=$CURRENT_TTL --type="A" --zone=$DNS_ZONE
fi
gcloud dns record-sets transaction add $INGRESS_IP --name=*.$BASE_DOMAIN \
--ttl="30" --type="A" --zone=$DNS_ZONE
# Run the transaction
gcloud dns record-sets transaction execute --zone=$DNS_ZONE

# Switch back to the main GCP project
gcloud config set project $CLUSTER_PROJECT
