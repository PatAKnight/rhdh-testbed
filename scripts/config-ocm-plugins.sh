#!/bin/bash

deploy_acm() {
  oc apply -f $PWD/resources/operators/acm-subscription.yaml --namespace=${NAMESPACE}
}

deploy_multicluster_hub() {
  SECONDS=0
  while true; do
    # Check if the operator CSV exists and its status
    STATUS=$(oc get csv --namespace=${NAMESPACE} | grep advanced-cluster-management | awk '{print $NF}')
    
    if [[ "$STATUS" == "Succeeded" ]]; then
      break
    fi

    # Check for timeout
    if [[ $SECONDS -ge $TIMEOUT ]]; then
      echo "Timeout waiting for the ACM operator to become ready."
      exit 1
    fi

    sleep "$INTERVAL"
    # Wait for the interval before checking again
    echo "ACM operator not ready yet. Retrying in $INTERVAL seconds..."
    sleep "$INTERVAL"
  done

  sleep "$INTERVAL"
  oc apply -f $PWD/resources/ocm/multi-cluster-hub.yaml --namespace=${NAMESPACE}
}

config_secrets_for_ocm_plugins() {
  sed -i "s|OCM_HUB_NAME:.*|OCM_HUB_NAME: $(echo -n "$OCM_HUB_NAME" | base64)|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
  sed -i "s|OCM_HUB_OWNERS:.*|OCM_HUB_OWNERS: $(echo -n "$OCM_HUB_OWNERS" | base64)|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
}

# TODO: Need to review all of the resources that are created through ACM and MultiClusterHub
apply_ocm_labels() {
  OPERATOR=$(oc get csv --namespace=${NAMESPACE} | grep advanced-cluster-management | awk '{print $1}')
  # Define the patters for for resource names
  declare -A patterns=(
    # Search
    ["search"]="backstage.io/kubernetes-id=search-operator"
  )

  # Define the label for pods
  declare -A app_labels=(
    # ACM
    ["olm.owner=$OPERATOR"]="backstage.io/kubernetes-id=acm-operator"
    # MultiClusterHub
    ["installer.name=multiclusterhub"]="backstage.io/kubernetes-id=multiclusterhub"
  )

  # Define the resource types to label
  resource_types=("pods" "deployments" "replicasets" "services" "routes" "ingresses" "statefulsets")

  # Loop through each pattern and apply the corresponding label
  for resource in "${resource_types[@]}"; do
    for pattern in "${!patterns[@]}"; do
      label="${patterns[$pattern]}"
      echo "Applying label '$label' to pods matching '$pattern'..."
      oc get "$resource" -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep "$pattern" | xargs -I {} oc label "$resource" {} "$label" --overwrite -n $NAMESPACE
    done

    # Loop through app labels and apply the corresponding labels
    for app in "${!app_labels[@]}"; do
      label="${app_labels[$app]}"
      echo "Applying label '$label' to $resource with label '$app'..."
      oc get "$resource" -l "$app" --no-headers -o custom-columns=":metadata.name" | xargs -I {} oc label "$resource" {} "$label" --overwrite
    done
  done
}

uninstall_acm() {
  # Delete OCM resources
  oc delete multiclusterhub multiclusterhub --namespace=${NAMESPACE}

  # Uninstall the operator
  OPERATOR=$(oc get csv --namespace=${NAMESPACE} | grep advanced-cluster-management | awk '{print $1}')
  oc delete clusterserviceversion $OPERATOR --namespace=${NAMESPACE}
  oc delete sub acm-operator-subscription --namespace=${NAMESPACE}
}

main() {
  source "${PWD}/env_variables.sh"
  source "${PWD}/.env"

  echo "Configuring resources for OCM plugins"
  deploy_acm

  deploy_multicluster_hub

  exit "${OVERALL_RESULT}" 
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi