#!/bin/bash

check_for_local_config_files() {
  # Check if the local rhdh secrets file exists
  if [ -f "$PWD/resources/user-resources/rhdh-secrets.local.yaml" ]; then
    echo "Local Secrets file already exists"
  else
    echo "Secrets does not exist, copying starting Secrets"
    cp $PWD/resources/rhdh/rhdh-secrets.yaml $PWD/resources/user-resources/rhdh-secrets.local.yaml
  fi

  # Check if the local app-config exists
  if [ -f "$PWD/resources/user-resources/app-config-rhdh.local.yaml" ]; then
    echo "Local App Config file already exists"
  else
    echo "App Config does not exist, copying starting App Config"
    cp $PWD/resources/rhdh/app-config-rhdh.yaml $PWD/resources/user-resources/app-config-rhdh.local.yaml
  fi

  # Check if the local dynamic plugins exists
  if [ -f "$PWD/resources/user-resources/dynamic-plugins-configmap.local.yaml" ]; then
    echo "Local Dynamic Plugins Config file already exists"
  else
    echo "Dynamic Plugins Config does not exist, copying starting Dynamic Plugins Config"
    cp $PWD/resources/rhdh/dynamic-plugins-configmap.yaml $PWD/resources/user-resources/dynamic-plugins-configmap.local.yaml
  fi

  # Check if the local RBAC Policies files exists
  if [ -f "$PWD/resources/user-resources/rbac-policies.local.yaml" ]; then
    echo "Local RBAC Policies file already exists"
  else
    echo "RBAC Policies does not exist, copying starting RBAC Policies"
    cp $PWD/resources/rhdh/rbac-policies.yaml $PWD/resources/user-resources/rbac-policies.local.yaml
  fi

  # Check if the local values files exists
  if [ -f "$PWD/resources/user-resources/values.local.yaml" ]; then
    echo "Local Values file already exists"
  else
    echo "Values does not exist, copying starting Values"
    cp $PWD/resources/rhdh/values.yaml $PWD/resources/user-resources/values.local.yaml
  fi
}

detect_cluster_router_base() {
  ROUTER_BASE=$(oc get ingress.config.openshift.io/cluster -o=jsonpath='{.spec.domain}')
}

detect_and_set_host() {
  # Detect cluster router base if not provided
  if [[ -z "$ROUTER_BASE" ]]; then
    detect_cluster_router_base
      if [ $? -eq 0 ]; then
        echo "Cluster router base detected: ${ROUTER_BASE}"
      else
        echo "Error: Cluster router base could not be automatically detected. This is most likely due to lack of permissions."
        echo "Using default value in the 'values.yaml' file. Please set it using the env variable ROUTER_BASE if you want a different router base."
      fi
  fi

  # Set global host if cluster router base is provided or detected
  if [[ -n "$ROUTER_BASE" ]]; then
    set -a
    GLOBAL_HOST="rhdh.${ROUTER_BASE}"
    set +a
    EXTRA_HELM_ARGS+=" --set global.host=$GLOBAL_HOST"
  fi
}

deploy_serviceaccount_resources() {
  # Change the namespace of the resources to the one namespace set above
  sed -i "s/namespace:.*/namespace: ${NAMESPACE}/g" ${PWD}/resources/service-accounts/service-account-rhdh.yaml
  sed -i "s/namespace:.*/namespace: ${NAMESPACE}/g" ${PWD}/resources/cluster-roles/cluster-role-binding-k8s.yaml
  sed -i "s/namespace:.*/namespace: ${NAMESPACE}/g" ${PWD}/resources/cluster-roles/cluster-role-binding-ocm.yaml

  # Cluster Service Account
  oc apply -f $PWD/resources/service-accounts/service-account-rhdh.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/service-accounts/service-account-rhdh-secret.yaml --namespace=${NAMESPACE}

  # ClusterRoles and ClusterRoleBindings
  oc apply -f $PWD/resources/cluster-roles/cluster-role-k8s.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/cluster-roles/cluster-role-binding-k8s.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/cluster-roles/cluster-role-ocm.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/cluster-roles/cluster-role-binding-ocm.yaml --namespace=${NAMESPACE}
}

deploy_operator_groups() {
  sed -i "s|<namespace>|$NAMESPACE|g" ${PWD}/resources/operators/operator-groups.yaml

  oc apply -f $PWD/resources/operators/operator-groups.yaml --namespace=${NAMESPACE}
}

deploy_image_stream_imports() {
  oc apply -f $PWD/resources/image-stream-imports/alpine-import.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/image-stream-imports/busy-box-import.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/image-stream-imports/nginxdemos-import.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/image-stream-imports/perl-import.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/image-stream-imports/redis-import.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/image-stream-imports/ubuntu-import.yaml --namespace=${NAMESPACE}
}

deploy_topology_resources() {
  # Upload Jobs and Cronjobs
  oc apply -f $PWD/resources/rhdh-script-examples/cron-job.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/rhdh-script-examples/pi-job.yaml --namespace=${NAMESPACE}

  # Upload Daemon Set
  oc apply -f $PWD/resources/rhdh-script-examples/daemon-set.yaml --namespace=${NAMESPACE}

  # # Upload Deployment
  oc apply -f $PWD/resources/rhdh-script-examples/backstage-test.yaml --namespace=${NAMESPACE}

  # Upload Stateful Set along with it's corresponding service resource
  oc apply -f $PWD/resources/rhdh-script-examples/stateful-set.yaml --namespace=${NAMESPACE}
}

deploy_redis() {
  oc apply -f $PWD/resources/redis-cache/redis.yaml --namespace=${NAMESPACE}

  set -a
  REDIS_USERNAME=$(echo -n "defaultuser" | base64)
  REDIS_PASSWORD=$(tr -cd '[:alnum:]' </dev/urandom | fold -w 10 | head -1 | tr -d '\n' | base64)
  set +a

  envsubst < $PWD/resources/redis-cache/redis-secret.yaml | oc apply -f - --namespace=${NAMESPACE}
}

deploy_catalog_entities() {
  oc apply -f $PWD/resources/catalog-entities/operators.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/catalog-entities/plugins.yaml --namespace=${NAMESPACE}
  envsubst < $PWD/resources/catalog-entities/components.yaml | oc apply -f - --namespace=${NAMESPACE}
}

deploy_resources() {
  deploy_serviceaccount_resources

  deploy_operator_groups

  deploy_image_stream_imports

  deploy_topology_resources

  deploy_redis

  deploy_catalog_entities
}

apply_user_configs() {
  oc apply -f $PWD/resources/user-resources/rbac-policies.local.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/user-resources/app-config-rhdh.local.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/user-resources/dynamic-plugins-configmap.local.yaml --namespace=${NAMESPACE}

  if [[ -n "$SIGN_IN_PAGE" ]]; then
    sed -i "s|SIGN_IN_PAGE:.*|SIGN_IN_PAGE: $(echo -n "$SIGN_IN_PAGE" | base64 -w 0)|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
  fi

  AUTH_SESSION_SECRET=$(tr -cd '[:alnum:]' </dev/urandom | fold -w 10 | head -1 | tr -d '\n')
  sed -i "s|AUTH_SESSION_SECRET:.*|AUTH_SESSION_SECRET: $(echo -n "$AUTH_SESSION_SECRET" | base64 -w 0)|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
  oc apply -f $PWD/resources/user-resources/rhdh-secrets.local.yaml --namespace=${NAMESPACE}
}

detect_user_credentials() {
  # If Keycloak is set, we generate some user credentials that can be used to log in with
  oc get secret credential-backstage-super-user-rhdh --namespace=${NAMESPACE} -o yaml > $PWD/auth/cluster-secrets/credential-backstage-super-user-rhdh.local.yaml
  USER_CREDENTIALS_ENCODED=$(grep 'password:' $PWD/auth/cluster-secrets/credential-backstage-super-user-rhdh.local.yaml | awk '{print $2}')
  USER_CREDENTIALS=$(echo "$USER_CREDENTIALS_ENCODED" | base64 -d)
  if [[ -n "$USER_CREDENTIALS" ]]; then
    echo "The user credentials for your RHDH instances are:"
    echo "  Username: super-user, Password: $USER_CREDENTIALS"
  fi
}

helm_install() {
    if [[ -z "${RELEASE_NAME}" ]]; then
    HELM_CMD="helm install --generate-name"
  else
    HELM_CMD="helm upgrade -i ${RELEASE_NAME}"
  fi

  HELM_CMD+=" ${HELM_REPO_NAME}/${HELM_CHART_NAME} --namespace ${NAMESPACE} -f $PWD/resources/user-resources/values.local.yaml ${EXTRA_HELM_ARGS} --version ${HELM_CHART_VERSION}"

  # Execute Helm install or upgrade command
  echo "Executing: ${HELM_CMD}"

  if eval "${HELM_CMD}"; then
    echo "Helm installation completed successfully."
    RHDH_ROUTE=$(oc get route $RELEASE_NAME-developer-hub -o=jsonpath='{.spec.host}')
    echo "Your RHDH instance can be accessed at: https://$RHDH_ROUTE"

    detect_user_credentials
  else
    echo "Something went wrong with Helm installation!"
    helm list --namespace "${NAMESPACE}"
    exit 1
  fi
}

main() {
  PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  # Load default variables
  source "${DIR}/env_variables.sh"

  # Load .env file if it exists (won't exist when running in-cluster)
  if [[ -f "${DIR}/.env" ]]; then
    source "${DIR}/.env"
    echo "Configuration loaded from .env file"
  elif [[ -n "${NAMESPACE:-}" ]]; then
    echo "Configuration loaded from environment variables (in-cluster mode)"
  else
    echo "ERROR: No configuration found."
    echo "Provide a .env file or set environment variables via ConfigMap/Secret."
    exit 1
  fi

  eval "$DIR/scripts/config-oc-and-helm.sh"

  check_for_local_config_files

  detect_and_set_host

  deploy_resources

  eval "$DIR/config-plugins.sh"

  apply_user_configs

  helm_install

  exit "${OVERALL_RESULT}" 
}

main