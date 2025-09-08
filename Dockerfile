FROM --platform=linux/amd64 fedora:41

RUN dnf install -y coreutils sed grep findutils gettext jq curl helm \
  && curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz \
  | tar -xz -C /usr/local/bin oc \
  && chmod +x /usr/local/bin/oc \
  && dnf clean all

WORKDIR /app

COPY . /app

RUN chmod +x /app/start.sh

ENTRYPOINT ["bash", "/app/start.sh"]
