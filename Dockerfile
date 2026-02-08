# Stage 1: Get oc binary from OpenShift image
FROM quay.io/openshift/origin-cli:latest AS oc-source

# Stage 2: Main application image
FROM --platform=linux/amd64 fedora:41

# OCI Labels
LABEL org.opencontainers.image.source="https://github.com/PatAKnight/rhdh-testbed"
LABEL org.opencontainers.image.description="RHDH Testbed - Quick deployment tools for Red Hat Developer Hub"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Copy oc binary from the official image
COPY --from=oc-source /usr/bin/oc /usr/local/bin/oc

RUN dnf install -y coreutils sed grep findutils gettext jq curl helm \
  && chmod +x /usr/local/bin/oc \
  && dnf clean all \
  && rm -rf /var/cache/dnf

WORKDIR /app

COPY . /app

RUN chmod +x /app/start.sh /app/teardown.sh /app/scripts/*.sh

# Support running as non-root (required for OpenShift restricted SCC)
RUN chown -R 1001:0 /app && chmod -R g=u /app

# Create writable directories for helm and oc caches
RUN mkdir -p /app/.cache /app/.config /app/.local/share/helm && \
    chown -R 1001:0 /app/.cache /app/.config /app/.local && \
    chmod -R g=u /app/.cache /app/.config /app/.local

# Set environment variables for helm and oc to use writable cache locations
ENV HOME=/app \
    XDG_CACHE_HOME=/app/.cache \
    XDG_CONFIG_HOME=/app/.config \
    XDG_DATA_HOME=/app/.local/share

USER 1001

# Default to start.sh, but allow override
# Use: docker run <image> bash /app/teardown.sh
ENTRYPOINT ["bash"]
CMD ["/app/start.sh"]
