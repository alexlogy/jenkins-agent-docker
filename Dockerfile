FROM debian:bullseye-slim

LABEL author="DevOps"
LABEL maintainer="alex@alexlogy.io"

WORKDIR /jenkins

ENV TZ='Asia/Singapore'
ENV LANG C.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL C.UTF-8

# Update and install dependencies
RUN apt-get update && apt-get -y install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    net-tools \
    curl \
    wget \
    nano \
    zip \
    unzip \
    python3 \
    python3-pip \
    openjdk-11-jre-headless \
    jq

# Install Docker
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
     $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    && systemctl enable docker \
    && service docker start

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf ./aws && rm -rf awscli-exe-linux-x86_64.zip

# Install Kubectl
RUN curl -o /usr/local/bin/kubectl -LO https://dl.k8s.io/release/v1.23.0/bin/linux/amd64/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install Helm
RUN wget https://get.helm.sh/helm-v3.9.2-linux-amd64.tar.gz \
    && tar zxvf helm-v*.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -rf linux-amd64 \
    && rm -rf helm-v*.tar.gz \
    && helm plugin install https://github.com/hypnoglow/helm-s3.git \
    && export HELM_S3_MODE=3

# Install Earthly
RUN wget https://github.com/earthly/earthly/releases/latest/download/earthly-linux-amd64 -O /usr/local/bin/earthly \
    && chmod +x /usr/local/bin/earthly

# Install Jenkins Remoting
RUN groupadd -g 10000 jenkins \
    && useradd -d /jenkins -u 10000 -g jenkins jenkins \
    && curl --create-dirs -sSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/4.9/remoting-4.9.jar \
    && chmod 755 /usr/share/jenkins \
    && chmod 644 /usr/share/jenkins/slave.jar

# Final Setup
COPY ./jenkins-slave.sh /usr/local/bin
COPY ./awsconfig /root/.aws/config
COPY ./awscredentials /root/.aws/credentials
COPY ./kubeconfig /root/.kube/config

RUN chmod +x /usr/local/bin/jenkins-slave.sh

# cleanup
RUN apt-get autoremove && apt-get clean && rm -rf /var/lib/apt/lists/*

## Docker Buildkit Activation
ENV DOCKER_BUILDKIT=1

RUN echo "hosts: files dns" >> /etc/nsswitch.conf

ENTRYPOINT service docker start && /usr/local/bin/jenkins-slave.sh
