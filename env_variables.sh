#!/bin/bash
set -a  # Automatically export all variables

HELM_REPO_NAME=openshift-helm-charts
HELM_REPO_URL=https://charts.openshift.io
HELM_CHART_NAME=redhat-developer-hub
HELM_CHART_VERSION=1.6.0
OVERALL_RESULT=0

RELEASE_NAME="backstage"
NAMESPACE="rhdh"

TIMEOUT=600  # Timeout in seconds
INTERVAL=10  # Check interval in seconds

# Plugin specific variables that need to be added to ensure we can reference them in separate scripts
USER_CREDENTIALS=''

set +a  # Stop automatically exporting variables
