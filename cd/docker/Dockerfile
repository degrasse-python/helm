FROM docker.io/cloudbees/cbflow-agent:10.3.5.152587_3.0.46_20211222

USER root
# install curl, git, vim, python3 via apt-get
RUN apt -y update && \
    apt -y install curl vim git python3 gnupg2 && \
    rm -rf /var/lib/apt/lists/*


RUN curl https://baltocdn.com/helm/signing.asc | apt-key add - && \
    apt install apt-transport-https --yes && \
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    apt update && \
    apt install helm -y && \
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
