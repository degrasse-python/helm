FROM docker.io/cloudbees/cbflow-agent:10.1.0.145850_2.1.12_20210224

USER root
# install curl, git, vim, python3 via apt-get
RUN apt-get -y update && \
    apt-get -y install curl vim git python3 gnupg2 && \
    rm -rf /var/lib/apt/lists/*


RUN curl https://baltocdn.com/helm/signing.asc | apt-key add - && \
    apt-get install apt-transport-https --yes && \
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    apt-get update && \
    apt-get install helm -y && \
    rm -rf /var/lib/apt/lists/*


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
