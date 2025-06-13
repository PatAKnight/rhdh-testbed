#!/bin/bash

deploy_rhsso() {
  oc apply -f $PWD/resources/operators/rhsso-subscription.yaml --namespace=${NAMESPACE}
}

deploy_keycloak_resources() {
  # Make sure that the operator is up and running
  SECONDS=0
  while true; do
    # Check if the Operator CSV exists and its status
    STATUS=$(oc get csv --namespace=${NAMESPACE} | grep rhsso-operator | awk '{print $NF}')

    if [[ "$STATUS" == "Succeeded" ]]; then
      break
    fi

    # Check for timeout
    if [[ $SECONDS -ge $TIMEOUT ]]; then
      echo "Timeout waiting for the RHSSO operator to become ready."
      exit 1
    fi

    # Wait for the interval before checking again
    echo "RHSSO operator not ready yet. Retrying in $INTERVAL seconds..."
    sleep "$INTERVAL"
  done

  oc apply -f $PWD/resources/keycloak/keycloak.yaml --namespace=${NAMESPACE}
  oc apply -f $PWD/resources/keycloak/keycloak-realm.yaml --namespace=${NAMESPACE}
  
  envsubst < $PWD/resources/keycloak/keycloak-client.yaml | oc apply -f - --namespace=${NAMESPACE}
}

config_secrets_for_keycloak_plugins() {
  #Make sure that the KeycloakClient is up and running
  SECONDS=0
  while true; do
    # Check if the operator CSV exists and its status
    READY=$(oc get keycloakclient keycloak --namespace=${NAMESPACE} -o jsonpath='{.status.ready}' 2>/dev/null)

    if [[ "$READY" == true ]]; then
        break
    fi

    # Check for timeout
    if [[ $SECONDS -ge $TIMEOUT ]]; then
      echo "Timeout waiting for the KeycloakClient to become ready."
      exit 1
    fi

    # Wait for the interval before checking again
    echo "KeycloakClient not ready yet. Retrying in $INTERVAL seconds..."
    sleep "$INTERVAL"
  done

  sleep "$INTERVAL"
  sleep "$INTERVAL"
  # Get keycloak secrets and set
  oc get secret keycloak-client-secret-keycloak --namespace=${NAMESPACE} -o yaml > $PWD/auth/cluster-secrets/keycloak-client-secret-keycloak.local.yaml
  KEYCLOAK_CLIENT_ID=$(grep 'CLIENT_ID:' $PWD/auth/cluster-secrets/keycloak-client-secret-keycloak.local.yaml | awk '{print $2}')
  sed -i "s|KEYCLOAK_CLIENT_ID:.*|KEYCLOAK_CLIENT_ID: $KEYCLOAK_CLIENT_ID|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
  KEYCLOAK_CLIENT_SECRET=$(grep 'CLIENT_SECRET:' $PWD/auth/cluster-secrets/keycloak-client-secret-keycloak.local.yaml | awk '{print $2}')
  sed -i "s|KEYCLOAK_CLIENT_SECRET:.*|KEYCLOAK_CLIENT_SECRET: $KEYCLOAK_CLIENT_SECRET|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
  KEYCLOAK_BASE_URL=$(oc get route keycloak --namespace=${NAMESPACE} -o jsonpath='{.spec.host}')
  sed -i "s|KEYCLOAK_BASE_URL:.*|KEYCLOAK_BASE_URL: $(echo -n "https://$KEYCLOAK_BASE_URL/auth" | base64 -w 0)|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
  KEYCLOAK_REALM=$(oc get keycloakrealm keycloak --namespace=${NAMESPACE} -o jsonpath='{.spec.realm.realm}')
  sed -i "s|KEYCLOAK_REALM:.*|KEYCLOAK_REALM: $(echo -n "$KEYCLOAK_REALM" | base64)|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml

  # We prefer to login using Keycloak and OIDC, so we go ahead and set the sign in page to OIDC
  sed -i "s|SIGN_IN_PAGE:.*|SIGN_IN_PAGE: $(echo -n "oidc" | base64)|g" $PWD/resources/user-resources/rhdh-secrets.local.yaml
}

create_users_and_groups_keycloak() {
  oc get secret credential-keycloak --namespace=${NAMESPACE} -o yaml > $PWD/auth/cluster-secrets/credential-keycloak.local.yaml
  ADMIN_PASSWORD_ENCODED=$(grep 'ADMIN_PASSWORD:' $PWD/auth/cluster-secrets/credential-keycloak.local.yaml | awk '{print $2}')
  ADMIN_PASSWORD=$(echo "$ADMIN_PASSWORD_ENCODED" | base64 -d)
  KEYCLOAK_URL=$(oc get route keycloak --namespace=${NAMESPACE} -o jsonpath='{.spec.host}')
  KEYCLOAK_REALM=$(oc get keycloakrealm keycloak --namespace=${NAMESPACE} -o jsonpath='{.spec.realm.realm}')
  USERNAME="admin"
  MASTERREALM="master"
  CLIENT_ID="admin-cli"

  ROOT_GROUP="marvel"
  groups=("avengers" "x-men" "fantastic-four" "guardians-of-the-galaxy" "x-force" "defenders" "cluster-admins")

  # Step 1: Get access token
  ACCESS_TOKEN=$(curl -s --insecure -X POST "https://$KEYCLOAK_URL/auth/realms/$MASTERREALM/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$USERNAME" \
    -d "password=$ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=$CLIENT_ID" | jq -r '.access_token')

  # Check if the access token was retrieved successfully
  if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
    echo "Failed to retrieve access token. Exiting."
    exit 1
  fi

  # Step 2: Create root group
  ROOT_GROUP_RESPONSE=$(curl -s --insecure -X POST "https://$KEYCLOAK_URL/auth/admin/realms/$KEYCLOAK_REALM/groups" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$ROOT_GROUP\"}")

  if [[ "$ROOT_GROUP_RESPONSE" != "" ]]; then
    echo "Failed to create root group '$ROOT_GROUP'. Response: $ROOT_GROUP_RESPONSE"
  else
    # Fetch the ID of the root group
    ROOT_GROUP_ID=$(curl -s --insecure -X GET "https://$KEYCLOAK_URL/auth/admin/realms/$KEYCLOAK_REALM/groups" \
      -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r ".[] | select(.name==\"$ROOT_GROUP\") | .id")

    if [ -z "$ROOT_GROUP_ID" ]; then
      echo "Failed to retrieve ID for root group '$ROOT_GROUP'."
    fi

    # Step 3: Create the child group in the specified realm
    for GROUP_NAME in "${groups[@]}"; do
      CREATE_GROUP_RESPONSE=$(curl -s --insecure -o /dev/null -w "%{http_code}" -X POST "https://$KEYCLOAK_URL/auth/admin/realms/$KEYCLOAK_REALM/groups" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$GROUP_NAME\"}")

      if [ "$CREATE_GROUP_RESPONSE" -eq 201 ]; then
        echo "Group '$GROUP_NAME' created successfully."
      else
        echo "Failed to create group '$GROUP_NAME'. HTTP status code: $CREATE_GROUP_RESPONSE"
      fi

      # Fetch the ID of the child group
      CHILD_GROUP_ID=$(curl -s --insecure -X GET "https://$KEYCLOAK_URL/auth/admin/realms/$KEYCLOAK_REALM/groups" \
        -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r ".[] | select(.name==\"$GROUP_NAME\") | .id")
      
      if [ -z "$CHILD_GROUP_ID" ]; then
        echo "Failed to retrieve ID for child group '$GROUP_NAME'. Skipping."
        continue
      fi

      # Assign the child group to the root group
      ASSIGN_RESPONSE=$(curl -s --insecure -X POST "https://$KEYCLOAK_URL/auth/admin/realms/$KEYCLOAK_REALM/groups/$ROOT_GROUP_ID/children" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"id\": \"$CHILD_GROUP_ID\", \"name\": \"$GROUP_NAME\"}")
      
      if [[ "$ASSIGN_RESPONSE" != "" ]]; then
        echo "Failed to assign child group '$GROUP_NAME' to root group '$ROOT_GROUP'. Response: $ASSIGN_RESPONSE"
      else
        echo "Child group '$GROUP_NAME' successfully assigned to root group '$ROOT_GROUP'."
      fi
    done
  fi

  set -a
  USER_CREDENTIALS=$(tr -cd '[:alnum:]' </dev/urandom | fold -w 10 | head -1 | tr -d '\n')
  set +a

  envsubst < $PWD/resources/keycloak/keycloak-users.yaml | oc apply -f - --namespace=${NAMESPACE} 
}

apply_keycloak_labels() {
  # Define the patterns for resource names
  declare -A patterns=(
    # RHSSO
    ["rhsso"]="backstage.io/kubernetes-id=rhsso-operator"
    # Keycloak
    ["keycloak"]="backstage.io/kubernetes-id=keycloak"
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
  done
}

uninstall_rhsso() {
  # Delete keycloak resources
  oc delete -f $PWD/resources/keycloak/keycloak-users.yaml --namespace=${NAMESPACE}
  oc delete keycloakclient keycloak --namespace=${NAMESPACE}
  oc delete keycloakrealm keycloak --namespace=${NAMESPACE}
  oc delete keycloak keycloak --namespace=${NAMESPACE}

  # Uninstall the operator
  OPERATOR=$(oc get csv --namespace=${NAMESPACE} | grep rhsso-operator | awk '{print $1}')
  oc delete clusterserviceversion $OPERATOR --namespace=${NAMESPACE}
  oc delete sub rhsso-operator-subscription --namespace=${NAMESPACE}
}

main() {
  source "${PWD}/env_variables.sh"
  source "${PWD}/.env"

  echo "Configuring resources for Keycloak plugins"
  deploy_rhsso
  
  deploy_keycloak_resources

  create_users_and_groups_keycloak

  exit "${OVERALL_RESULT}" 
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi