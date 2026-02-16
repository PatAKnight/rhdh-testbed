#!/bin/bash

copy_3scale_files() {
  if [ -f "$PWD/resources/user-resources/minio-secret.local.yaml" ]; then
    echo "Local Minio Secrets file already exists"
  else
    echo "Minio Secrets file does not exist, copying starting Minio Secrets"
    cp $PWD/resources/minio/minio-secret.yaml $PWD/resources/user-resources/minio-secret.local.yaml
  fi

  if [ -f "$PWD/resources/user-resources/3scale-secret.local.yaml" ]; then
    echo "Local 3Scale Secrets file already exists"
  else
    echo "3Scale Secrets file does not exist, copying starting 3Scale Secrets"
    cp $PWD/resources/3scale/3scale-secret.yaml $PWD/resources/user-resources/3scale-secret.local.yaml
  fi
}

deploy_3scale() {
  oc apply -f $PWD/resources/operators/3scale-subscription.yaml --namespace=${NAMESPACE}
}

deploy_minio() {
  oc apply -f $PWD/resources/minio/deployment.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/minio/persistent-volume-claim.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/minio/service.yaml --namespace=${NAMESPACE}

  MINIO_ROOT_PASSWORD=$(openssl rand -base64 16)
  # MINIO_ROOT_PASSWORD="minioadmin"
  sed -i "s|minio_root_password:.*|minio_root_password: $(echo -n "$MINIO_ROOT_PASSWORD" | base64 -w 0)|g" $PWD/resources/user-resources/minio-secret.local.yaml
  MINIO_ROOT_USER=$(openssl rand -base64 16)
  # MINIO_ROOT_USER="minioadmin"
  sed -i "s|minio_root_user:.*|minio_root_user: $(echo -n "$MINIO_ROOT_USER" | base64 -w 0)|g" $PWD/resources/user-resources/minio-secret.local.yaml
  oc apply -f $PWD/resources/user-resources/minio-secret.local.yaml --namespace ${NAMESPACE}

  AWS_HOST="http://minio.$NAMESPACE.svc.cluster.local:9000"
  AWS_BUCKET="3scale"
  AWS_REGION="eu-west-3"
  sed -i "s|AWS_HOST:.*|AWS_HOST: $(echo -n "$AWS_HOST" | base64 -w 0)|g" $PWD/resources/user-resources/3scale-secret.local.yaml
  sed -i "s|AWS_SECRET_ACCESS_KEY:.*|AWS_SECRET_ACCESS_KEY: $(echo -n "$MINIO_ROOT_PASSWORD" | base64 -w 0)|g" $PWD/resources/user-resources/3scale-secret.local.yaml
  sed -i "s|AWS_ACCESS_KEY_ID:.*|AWS_ACCESS_KEY_ID: $(echo -n "$MINIO_ROOT_USER" | base64 -w 0)|g" $PWD/resources/user-resources/3scale-secret.local.yaml
  sed -i "s|AWS_BUCKET:.*|AWS_BUCKET: $(echo -n "$AWS_BUCKET" | base64 -w 0)|g" $PWD/resources/user-resources/3scale-secret.local.yaml
  sed -i "s|AWS_REGION:.*|AWS_REGION: $(echo -n "$AWS_REGION" | base64 -w 0)|g" $PWD/resources/user-resources/3scale-secret.local.yaml
  oc apply -f $PWD/resources/user-resources/3scale-secret.local.yaml --namespace ${NAMESPACE}
}

deploy_3scale_resources() {
  set -a
  # shellcheck disable=SC2034
  ROUTER_BASE=$(oc get ingress.config.openshift.io/cluster -o=jsonpath='{.spec.domain}')
  set +a
  
  envsubst < $PWD/resources/3scale/api-manager.yaml | oc apply -f - --namespace=${NAMESPACE} 
  oc apply -f $PWD/resources/3scale/active-doc.yaml --namespace=${NAMESPACE}
}

# apply_3scale_labels() {

# }

uninstall_3scale() {
  # Delete 3scale resources
  oc delete -f $PWD/resources/3scale/active-doc.yaml --namespace=${NAMESPACE}
  oc delete secret 3scale --namespace=${NAMESPACE}
  oc delete apimanager 3scale --namespace=${NAMESPACE}

  # Uninstall the operator
  OPERATOR=$(oc get csv --namespace=${NAMESPACE} | grep rhsso-operator | awk '{print $1}')
  oc delete clusterserviceversion $OPERATOR --namespace=${NAMESPACE}
  oc delete sub rhsso-operator-subscription --namespace=${NAMESPACE}

  # Delete minio resources
  oc delete secret minio --namespace=${NAMESPACE}
  oc delete service minio --namespace=${NAMESPACE}
  oc delete deployment minio --namespace=${NAMESPACE}
  oc delete persistentvolumeclaim minio --namespace=${NAMESPACE}
}

main() {
  source "${PWD}/env_variables.sh"
  source "${PWD}/.env"

  echo "Configuring resources for 3scale plugin"
  copy_3scale_files

  deploy_3scale

  deploy_minio

  deploy_3scale_resources

  exit "${OVERALL_RESULT}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
