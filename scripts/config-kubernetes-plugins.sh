#!/bin/bash

config_secrets_for_kubernetes_plugins() {
  # Get cluster token and set k8s secrets
  oc get secret rhdh-k8s-plugin-secret --namespace=${NAMESPACE} -o yaml > $PWD/auth/cluster-secrets/service-account-rhdh-token.local.yaml
  TOKEN=$(grep 'token:' $PWD/auth/cluster-secrets/service-account-rhdh-token.local.yaml | awk '{print $2}')
  sed -i "s/K8S_CLUSTER_TOKEN:.*/K8S_CLUSTER_TOKEN: $TOKEN/g" $PWD/resources/user-resources/rhdh-secrets.local.yaml

  # Resolve K8S_CLUSTER_URL: auto-discover ONLY when running as a cluster Job.
  # Never auto-discover locally — the user could be logged into the wrong cluster.
  if [[ -z "${K8S_CLUSTER_URL:-}" ]]; then
    if [[ "${IN_CLUSTER:-false}" == "true" ]]; then
      echo "K8S_CLUSTER_URL not set — discovering from cluster Infrastructure CR..."
      K8S_CLUSTER_URL=$(oc get infrastructure cluster \
        -o jsonpath='{.status.apiServerURL}' 2>/dev/null)
      if [[ -z "$K8S_CLUSTER_URL" ]]; then
        echo "ERROR: Could not determine K8S_CLUSTER_URL from cluster. Set it explicitly in the Secret."
        exit 1
      fi
      echo "Discovered K8S_CLUSTER_URL: $K8S_CLUSTER_URL"
    else
      echo "ERROR: K8S_CLUSTER_URL is required. Set it in your .env file."
      exit 1
    fi
  fi

  sed -i "s#K8S_CLUSTER_URL:.*#K8S_CLUSTER_URL: $(echo -n "$K8S_CLUSTER_URL" | base64 -w 0)#g" \
    $PWD/resources/user-resources/rhdh-secrets.local.yaml
  sed -i "s|K8S_CLUSTER_NAME:.*|K8S_CLUSTER_NAME: $(echo -n "$K8S_CLUSTER_NAME" | base64)|g" \
    $PWD/resources/user-resources/rhdh-secrets.local.yaml
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