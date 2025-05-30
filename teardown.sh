#!/bin/bash

uninstall_helm(){
  if [ -z "${RELEASE_NAME}" ]; then
    echo "Please provide the helm release name to uninstall the helm chart."
    helm list --namespace "${NAMESPACE}"
    exit 1
  fi
  helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}
  echo "Please delete any persistent volume claims that were created by the helm chart for a full uninstall."
  echo "Otherwise, leave them be and the next install with the same helm release name will reuse them."
}

uninstall_serviceaccount_resources() {
  # ClusterRoles and ClusterRoleBindings
  oc delete clusterrole rhdh-k8s-plugin --namespace=${NAMESPACE}
  oc delete clusterrole rhdh-k8s-plugin-ocm --namespace=${NAMESPACE}
  oc delete clusterrolebinding rhdh-k8s-plugin
  oc delete clusterrolebinding rhdh-k8s-plugin-ocm

  # Cluster Service Account
  oc delete serviceaccount rhdh-k8s-plugin --namespace=${NAMESPACE}
}

uninstall_operator_group() {
  oc delete operatorgroup default-operator-group --namespace=${NAMESPACE}
}

uninstall_topology_resources() {
  # Deployments
  oc delete deployment backstage-app --namespace=${NAMESPACE}

  # Upload Jobs and Cronjobs
  oc delete cronjob say-hello --namespace=${NAMESPACE}
  oc delete job print-pi --namespace=${NAMESPACE}

  # Daemon Set
  oc delete daemonset test-daemonset --namespace=${NAMESPACE}

  # Stateful Set along with it's corresponding service resource
  oc delete statefulset example-statefulset --namespace=${NAMESPACE}
  oc delete service example-service --namespace=${NAMESPACE}
}

uninstall_redis() {
  oc delete deployment redis --namespace=${NAMESPACE}
  oc delete service redis --namespace=${NAMESPACE}
  oc delete secret redis-secret --namespace=${NAMESPACE}
}

uninstall_catalog_entities() {
  oc delete configmap operators-config-map --namespace=${NAMESPACE}
  oc delete configmap plugins-config-map --namespace=${NAMESPACE}
  oc delete configmap components-config-map --namespace=${NAMESPACE}
}

uninstall_resources() {
  uninstall_serviceaccount_resources

  uninstall_operator_group

  uninstall_topology_resources

  uninstall_redis

  uninstall_catalog_entities
}

uninstall_configs() {
  # ConfigMaps and Secrets
  oc delete configmap rhdh-dynamic-plugins --namespace=${NAMESPACE}
  oc delete configmap app-config-rhdh --namespace=${NAMESPACE}
  oc delete secret rhdh-secrets --namespace=${NAMESPACE}
  oc delete configmap rbac-policy --namespace=${NAMESPACE}
}

uninstall_project() {
  oc delete project ${NAMESPACE}
}

main() {
  PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  source "${DIR}/env_variables.sh"
  source "${DIR}/.env"

  eval "$DIR/scripts/config-oc-and-helm.sh"

  set -a
  TEARDOWN=true
  set +a

  eval "$DIR/config-plugins.sh"

  uninstall_helm

  uninstall_resources

  uninstall_configs

  # uninstall_project

  exit "${OVERALL_RESULT}" 
}

main
