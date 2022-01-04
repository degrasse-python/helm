FROM docker.io/cloudbees/cbflow-agent:10.3.2.151906_3.0.37_20211116
USER root
# install curl, git, vim, python3 via apt-get
RUN yum -y update && \
  yum -y install curl vim git python3 gnupg2 && \
  rm -rf /var/lib/apt/lists/*
# Install helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
chmod 700 get_helm.sh && \
./get_helm.sh
USER cbflow
WORKDIR /home/cbflow
# install gcloud
RUN curl https://sdk.cloud.google.com > install.sh
RUN bash install.sh --disable-prompts
# install kubectl
RUN /home/cbflow/google-cloud-sdk/bin/gcloud components install kubectl
USER root
RUN mv /home/cbflow/google-cloud-sdk/bin/* /usr/local/bin/
USER cbflow
