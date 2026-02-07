#!/bin/bash

install_oc() {
  if [[ -x "$(command -v oc)" ]]; then
    echo "oc is already installed."
  else
    # curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/linux/oc.tar.gz
    # tar -xf oc.tar.gz
    # mv oc /usr/local/bin/
    # rm oc.tar.gz
    # echo "oc installed successfully."
    echo "Recommend installing oc (OpenShift CLI) to continue"
    exit 1
  fi
}

oc_login() {
  local TARGET_SERVER=""
  local CURRENT_SERVER=""
  
  # Determine the target server based on mode
  if [[ "${IN_CLUSTER:-false}" == "true" ]]; then
    TARGET_SERVER="https://kubernetes.default.svc"
  else
    if [[ -z "${K8S_CLUSTER_URL:-}" ]]; then
      echo "ERROR: K8S_CLUSTER_URL is required when not running in-cluster"
      exit 1
    fi
    TARGET_SERVER="${K8S_CLUSTER_URL}"
  fi
  
  # Check if already logged in
  if oc whoami &>/dev/null; then
    CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null)
    
    # Normalize URLs for comparison (remove trailing slashes)
    CURRENT_SERVER="${CURRENT_SERVER%/}"
    TARGET_SERVER_NORMALIZED="${TARGET_SERVER%/}"
    
    if [[ "$CURRENT_SERVER" == "$TARGET_SERVER_NORMALIZED" ]]; then
      echo "Already logged in to target cluster as: $(oc whoami)"
      echo "  Server: $CURRENT_SERVER"
      return 0
    else
      echo "WARNING: Currently logged in to different cluster!"
      echo "  Current: $CURRENT_SERVER"
      echo "  Target:  $TARGET_SERVER"
      echo "Switching to target cluster..."
    fi
  fi

  # Perform login to target cluster
  if [[ "${IN_CLUSTER:-false}" == "true" ]]; then
    echo "Running in-cluster, using ServiceAccount authentication..."
    
    local SA_TOKEN_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"
    local SA_CA_PATH="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    
    if [[ -f "$SA_TOKEN_PATH" ]]; then
      oc login --token="$(cat $SA_TOKEN_PATH)" \
               --server="$TARGET_SERVER" \
               --certificate-authority="$SA_CA_PATH"
    else
      echo "ERROR: IN_CLUSTER=true but ServiceAccount token not found at $SA_TOKEN_PATH"
      exit 1
    fi
  else
    echo "Authenticating to: $TARGET_SERVER"
    
    if [[ -z "${K8S_CLUSTER_TOKEN:-}" ]]; then
      echo "ERROR: K8S_CLUSTER_TOKEN is required when not running in-cluster"
      exit 1
    fi
    
    oc login --token="${K8S_CLUSTER_TOKEN}" \
             --server="${K8S_CLUSTER_URL}"
  fi
  
  # Verify login succeeded to the correct cluster
  CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null)
  echo "Successfully logged in as: $(oc whoami)"
  echo "  Server: $CURRENT_SERVER"
}

set_namespace() {
  # Create Namespace and switch to it
  oc new-project ${NAMESPACE}
  if [ $? -ne 0 ]; then
    # Switch to it if it already exists
    oc project ${NAMESPACE}
  fi
}

install_helm_release() {
  if [[ -x "$(command -v helm)" ]]; then
    echo "Helm is already installed."
  else
    # echo "Installing Helm 3 client"
    # WORKING_DIR=$(pwd)
    # mkdir ~/tmpbin && cd ~/tmpbin

    # HELM_INSTALL_DIR=$(pwd)
    # curl -sL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -f
    # export PATH=${HELM_INSTALL_DIR}:$PATH

    # cd $WORKING_DIR
    # echo "helm client installed successfully."

    echo "Recommend installing helm to continue"
    exit 1
  fi
}

add_helm_repo() {
  helm version

  # Check if the repository already exists
  if ! helm repo list | grep -q "^${HELM_REPO_NAME}"; then
    helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}"
  else
    echo "Repository ${HELM_REPO_NAME} already exists - updating repository instead."
    helm repo update
  fi
}

load_config() {
  # Load default variables
  source "${PWD}/env_variables.sh"
  
  # Environment variables take precedence (set by ConfigMap/Secret in k8s)
  # Only source .env if it exists (won't exist when running in-cluster)
  if [[ -f "${PWD}/.env" ]]; then
    source "${PWD}/.env"
    echo "Configuration loaded from .env file"
  elif [[ -n "${NAMESPACE:-}" ]]; then
    echo "Configuration loaded from environment variables"
  else
    echo "ERROR: No configuration found."
    echo "Set environment variables, provide .env file, or deploy with ConfigMap/Secret."
    exit 1
  fi
}

main() {
  load_config

  install_oc

  oc_login

  set_namespace

  install_helm_release

  add_helm_repo

  exit "${OVERALL_RESULT}" 
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi