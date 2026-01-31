FROM --platform=linux/amd64 fedora:41

# OCI Labels
LABEL org.opencontainers.image.source="https://github.com/PatAKnight/rhdh-testbed"
LABEL org.opencontainers.image.description="RHDH Testbed - Quick deployment tools for Red Hat Developer Hub"
LABEL org.opencontainers.image.licenses="Apache-2.0"

RUN dnf install -y coreutils sed grep findutils gettext jq curl helm \
  && curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz \
  | tar -xz -C /usr/local/bin oc \
  && chmod +x /usr/local/bin/oc \
  && dnf clean all \
  && rm -rf /var/cache/dnf

WORKDIR /app

COPY . /app

RUN chmod +x /app/start.sh /app/teardown.sh /app/scripts/*.sh

# Support running as non-root (required for OpenShift restricted SCC)
RUN chown -R 1001:0 /app && chmod -R g=u /app
USER 1001

# Default to start.sh, but allow override
# Use: docker run <image> bash /app/teardown.sh
ENTRYPOINT ["bash"]
CMD ["/app/start.sh"]
