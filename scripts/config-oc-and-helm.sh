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
  oc login --token="${K8S_CLUSTER_TOKEN}" --server="${K8S_CLUSTER_URL}"
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

main() {
  source "${PWD}/env_variables.sh"
  source "${PWD}/.env"

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