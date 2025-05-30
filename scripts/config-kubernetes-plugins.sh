#!/bin/bash

config_secrets_for_kubernetes_plugins() {
  # Get cluster token and set k8s secrets
  oc get secret rhdh-k8s-plugin-secret --namespace=${NAMESPACE} -o yaml > $PWD/auth/cluster-secrets/service-account-rhdh-token.local.yaml
  TOKEN=$(grep 'token:' $PWD/auth/cluster-secrets/service-account-rhdh-token.local.yaml | awk '{print $2}')
  sed -i "s/K8S_CLUSTER_TOKEN:.*/K8S_CLUSTER_TOKEN: $TOKEN/g" $PWD/resources/user-resources/rhdh-secrets.local.yaml

  sed -i "s#K8S_CLUSTER_URL:.*#K8S_CLUSTER_URL: $(echo -n "$K8S_CLUSTER_URL" | base64 -w 0)#g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
  sed -i "s|K8S_CLUSTER_NAME:.*|K8S_CLUSTER_NAME: $(echo -n "$K8S_CLUSTER_NAME" | base64)|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
}


main() {
  source "${PWD}/env_variables.sh"
  source "${PWD}/.env"

  echo "Configuring resources for Kubernetes plugins"
  config_secrets_for_kubernetes_plugins

  exit "${OVERALL_RESULT}" 
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi