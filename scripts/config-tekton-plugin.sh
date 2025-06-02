#!/bin/bash

deploy_tekon() {
  oc apply -f $PWD/resources/operators/openshift-pipelines.yaml
}

deploy_pipelines() {
  SECONDS=0
  while true; do
    # Check if the operator CSV exists and its status
    STATUS=$(oc get csv --namespace="openshift-operators" | grep openshift-pipelines-operator-rh | awk '{print $NF}')

    if [[ "$STATUS" == "Succeeded" ]]; then
      sleep "$INTERVAL"
      break
    fi

    # Check for timeout
    if [[ $SECONDS -ge $TIMEOUT ]]; then
      echo "Timeout waiting for the OpenShift Pipelines operator to become ready."
      exit 1
    fi

    # Wait for the interval before checking again
    echo "OpenShift Pipelines operator not ready yet. Retrying in $INTERVAL seconds..."
    sleep "$INTERVAL"
  done

  # TODO: There are a number of sleeps here, this is because I have noticed that even though the CSV status says succeeded, some of the resources might not
  # be available just yet. Need to check that those are ready as well before deploying the resources in this project
  # under the namespace openshift pipelines, there are a number of pods that I should be able to use as checks for if it is ready
  sleep "$INTERVAL"
  sleep "$INTERVAL"
  # Pipelines to test Tekton plugin
  envsubst < $PWD/resources/tekton/hello-world-pipeline.yaml | oc apply -f - --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/tekton/hello-world-pipeline-run.yaml --namespace=${NAMESPACE}
}

apply_tekton_labels() {
  # Define the patters for resource names
  declare -A patterns=(
    # Tekton
    ["tekton"]="backstage.io/kubernetes-id=pipelines-operator"
    ["pipelines-as-code"]="backstage.io/kubernetes-id=pipelines-operator"
    ["tkn"]="backstage.io/kubernetes-id=pipelines-operator"
  )

  # Define the resource types to label
  resource_types=("pods" "deployments" "replicasets" "services" "routes" "ingresses" "statefulsets")

  # Loop through each pattern and apply the corresponding label
  for resource in "${resource_types[@]}"; do
    for pattern in "${!patterns[@]}"; do
      label="${patterns[$pattern]}"
      echo "Applying label '$label' to pods matching '$pattern'..."
      oc get "$resource" -n openshift-pipelines --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep "$pattern" | xargs -I {} oc label "$resource" {} "$label" --overwrite -n openshift-pipelines
    done
  done
}

uninstall_tekton() {
  # Delete the pipeline resources
  oc delete pipeline hello-world-pipeline --namespace=${NAMESPACE}
  oc delete pipelinerun hello-world-pipeline-run --namespace=${NAMESPACE}

  # Uninstall the operator
  OPERATOR=$(oc get csv --namespace="openshift-operators" | grep openshift-pipelines-operator-rh | awk '{print $1}')
  oc delete clusterserviceversion $OPERATOR --namespace="openshift-operators"
  oc delete sub openshift-pipelines-operator --namespace="openshift-operators"
}

main() {
  source "${PWD}/env_variables.sh"
  source "${PWD}/.env"

  echo "Configuring resources for Tekton plugins"
  deploy_tekon

  deploy_pipelines

  apply_tekton_labels

  exit "${OVERALL_RESULT}" 
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi