#!/bin/bash
set -a  # Automatically export all variables

# Use this for the RHDH chart from the Red Hat Developer GitHub repository
HELM_REPO_NAME=rhdh-chart
HELM_REPO_URL=https://redhat-developer.github.io/rhdh-chart/
HELM_CHART_NAME=backstage
HELM_CHART_VERSION=5.2.0  # community version numbering

# Use this for the upstream Red Hat Developer Hub chart
# HELM_REPO_NAME=openshift-helm-charts
# HELM_REPO_URL=https://charts.openshift.io
# HELM_CHART_NAME=redhat-developer-hub
# HELM_CHART_VERSION=1.9.0
OVERALL_RESULT=0

RELEASE_NAME="backstage"
NAMESPACE="rhdh"

TIMEOUT=600  # Timeout in seconds
INTERVAL=10  # Check interval in seconds

# Plugin specific variables that need to be added to ensure we can reference them in separate scripts
USER_CREDENTIALS=''

set +a  # Stop automatically exporting variables
