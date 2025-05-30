#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
for file in ${DIR}/scripts/*.sh; do source $file; done

declare -A plugin_resources=()

get_enabled_plugins() {
  while read -r status; do
    PLUGIN_STATUSES+=("$status")
  done < <(awk '$1 ~ /disabled:/ { print $2 }' "$CONFIGMAP_FILE")

  while read -r plugin; do
    PLUGINS+=("$plugin")
  done < <(awk '$1 == "-" && $2 == "package:" { print $3 }' "$CONFIGMAP_FILE")
}

set_enabled_plugins() {
  for i in "${!PLUGIN_STATUSES[@]}"; do
    if [[ "${PLUGIN_STATUSES[$i]}" == "false" ]]; then
      # The package is enabled, decide which function to call
      case $i in
        1|2|3|4|5|6|7) 
          if [[ -z "${GITHUB_PLUGINS_CONFIGURED+x}" || "$GITHUB_PLUGINS_CONFIGURED" == false ]]; then
            GITHUB_PLUGINS_CONFIGURED=true
          fi
          ;;
        9|10|11|12) 
          if [[ -z "${GITLAB_PLUGINS_CONFIGURED+x}" || "$GITLAB_PLUGINS_CONFIGURED" == false ]]; then
            GITLAB_PLUGINS_CONFIGURED=true
          fi
          ;;
        13|14|15) 
          if [[ -z "${KUBERNETES_PLUGINS_CONFIGURED+x}" || "$KUBERNETES_PLUGINS_CONFIGURED" == false ]]; then
            KUBERNETES_PLUGINS_CONFIGURED=true
          fi
          ;;
        16|17|18|19)
          if [[ -z "${ARGOCD_PLUGINS_CONFIGURED+x}" || "$ARGOCD_PLUGINS_CONFIGURED" == false ]]; then
            ARGOCD_PLUGINS_CONFIGURED=true
          fi
          ;;
        21|22)
          if [[ -z "${AZURE_PLUGINS_CONFIGURED+x}" || "$AZURE_PLUGINS_CONFIGURED" == false ]]; then
            AZURE_PLUGINS_CONFIGURED=true
          fi
          ;;
        24|25)
          if [[ -z "${JENKINS_PLUGINS_CONFIGURED+x}" || "$JENKINS_PLUGINS_CONFIGURED" == false ]]; then
            JENKINS_PLUGINS_CONFIGURED=true
          fi
          ;;
        26|27|28|29|30)
          if [[ -z "${NOTIFICATIONS_PLUGINS_CONFIGURED+x}" || "$NOTIFICATIONS_PLUGINS_CONFIGURED" == false ]]; then
            NOTIFICATIONS_PLUGINS_CONFIGURED=true
          fi
          ;;
        31|32)
          if [[ -z "${SONARQUBE_PLUGINS_CONFIGURED+x}" || "$SONARQUBE_PLUGINS_CONFIGURED" == false ]]; then
            SONARQUBE_PLUGINS_CONFIGURED=true
          fi
          ;;
        33|34) 
          if [[ -z "${OCM_PLUGINS_CONFIGURED+x}" || "$OCM_PLUGINS_CONFIGURED" == false ]]; then
            OCM_PLUGINS_CONFIGURED=true
          fi
          ;;
        35|36) 
          if [[ -z "${BULK_IMPORT_PLUGINS_CONFIGURED+x}" || "$BULK_IMPORT_PLUGINS_CONFIGURED" == false ]]; then
            BULK_IMPORT_PLUGINS_CONFIGURED=true
          fi
          ;;
        40|41)
          if [[ -z "${TECHDOCS_PLUGINS_CONFIGURED+x}" || "$TECHDOCS_PLUGINS_CONFIGURED" == false ]]; then
            TECHDOCS_PLUGINS_CONFIGURED=true
          fi
          ;;
        43|44)
          if [[ -z "${PAGERDUTY_PLUGINS_CONFIGURED+x}" || "$PAGERDUTY_PLUGINS_CONFIGURED" == false ]]; then
            PAGERDUTY_PLUGINS_CONFIGURED=true
          fi
          ;;
        51) 
          if [[ -z "${RBAC_PLUGINS_CONFIGURED+x}" || "$RBAC_PLUGINS_CONFIGURED" == false ]]; then
            RBAC_PLUGINS_CONFIGURED=true
          fi
          ;;
        52)
          if [[ -z "${SERVICENOW_PLUGINS_CONFIGURED+x}" || "$SERVICENOW_PLUGINS_CONFIGURED" == false ]]; then
            SERVICENOW_PLUGINS_CONFIGURED=true
          fi
          ;;
        42)
          if [[ -z "${TECHDOCS_CONTRIB_PLUGINS_CONFIGURED+x}" || "$TECHDOCS_CONTRIB_PLUGINS_CONFIGURED" == false ]]; then
            TECHDOCS_CONTRIB_PLUGINS_CONFIGURED=true
          fi
          ;;
        54)
          if [[ -z "${THREESCALE_PLUGINS_CONFIGURED+x}" || "$THREESCALE_PLUGINS_CONFIGURED" == false ]]; then
            THREESCALE_PLUGINS_CONFIGURED=true
          fi
          ;;
        55) 
          if [[ -z "${KEYCLOAK_PLUGINS_CONFIGURED+x}" || "$KEYCLOAK_PLUGINS_CONFIGURED" == false ]]; then
            KEYCLOAK_PLUGINS_CONFIGURED=true
          fi
          ;;
        57|59)
          if [[ -z "${BITBUCKET_PLUGINS_CONFIGURED+x}" || "$BITBUCKET_PLUGINS_CONFIGURED" == false ]]; then
            BITBUCKET_PLUGINS_CONFIGURED=true
          fi
          ;;
        60)
          if [[ -z "${DYNATRACE_PLUGINS_CONFIGURED+x}" || "$DYNATRACE_PLUGINS_CONFIGURED" == false ]]; then
            DYNATRACE_PLUGINS_CONFIGURED=true
          fi
          ;;
        61)
          if [[ -z "${JIRA_PLUGINS_CONFIGURED+x}" || "$JIRA_PLUGINS_CONFIGURED" == false ]]; then
            JIRA_PLUGINS_CONFIGURED=true
          fi
          ;;
        62)
          if [[ -z "${DATADOG_PLUGINS_CONFIGURED+x}" || "$DATADOG_PLUGINS_CONFIGURED" == false ]]; then
            DATADOG_PLUGINS_CONFIGURED=true
          fi
          ;;
        63) 
          if [[ -z "${TEKTON_PLUGINS_CONFIGURED+x}" || "$TEKTON_PLUGINS_CONFIGURED" == false ]]; then
            TEKTON_PLUGINS_CONFIGURED=true
          fi
          ;;
        64) 
          if [[ -z "${QUAY_PLUGINS_CONFIGURED+x}" || "$QUAY_PLUGINS_CONFIGURED" == false ]]; then
            QUAY_PLUGINS_CONFIGURED=true
          fi
          ;;
        65) 
          if [[ -z "${NEXUS_PLUGINS_CONFIGURED+x}" || "$NEXUS_PLUGINS_CONFIGURED" == false ]]; then
            NEXUS_PLUGINS_CONFIGURED=true
          fi
          ;;
        66)
          if [[ -z "${ACR_PLUGINS_CONFIGURED+x}" || "$ACR_PLUGINS_CONFIGURED" == false ]]; then
            ACR_PLUGINS_CONFIGURED=true
          fi
          ;;
        67)
          if [[ -z "${JFROG_PLUGINS_CONFIGURED+x}" || "$JFROG_PLUGINS_CONFIGURED" == false ]]; then
            JFROG_PLUGINS_CONFIGURED=true
          fi
          ;;
        68)
          if [[ -z "${LIGHTHOUSE_PLUGINS_CONFIGURED+x}" || "$LIGHTHOUSE_PLUGINS_CONFIGURED" == false ]]; then
            LIGHTHOUSE_PLUGINS_CONFIGURED=true
          fi
          ;;
        69|70) 
          if [[ -z "${TECH_RADAR_PLUGINS_CONFIGURED+x}" || "$TECH_RADAR_PLUGINS_CONFIGURED" == false ]]; then
            TECH_RADAR_PLUGINS_CONFIGURED=true
          fi
          ;;
        71)
          if [[ -z "${ANALYTICS_PLUGINS_CONFIGURED+x}" || "$ANALYTICS_PLUGINS_CONFIGURED" == false ]]; then
            ANALYTICS_PLUGINS_CONFIGURED=true
          fi
          ;;
        73)
          if [[ -z "${MSGRAPH_PLUGINS_CONFIGURED+x}" || "$MSGRAPH_PLUGINS_CONFIGURED" == false ]]; then
            MSGRAPH_PLUGINS_CONFIGURED=true
          fi
          ;;
        74)
          if [[ -z "${LDAP_PLUGINS_CONFIGURED+x}" || "$LDAP_PLUGINS_CONFIGURED" == false ]]; then
            LDAP_PLUGINS_CONFIGURED=true
          fi
          ;;
        75)
          if [[ -z "${PINGIDENTITY_PLUGINS_CONFIGURED+x}" || "$PINGIDENTITY_PLUGINS_CONFIGURED" == false ]]; then
            PINGIDENTITY_PLUGINS_CONFIGURED=true
          fi
          ;;
        0|8|20|23|45|46|47|48|49|50|53|56|58)
          echo "Scaffolder dynamic plugins are pre-enabled, ensure that you have set the appropriate integrations for any planned use" ;;
        *) echo "No function defined for package $((i + 1))" ;;
      esac
    else
      # The package is disabled
      echo "Package ${PLUGINS[$i]} is disabled. Skipping."
    fi
  done
}

set_plugin_function_mappings() {
  # Configuring enabled plugins if we are not tearing down.
  if [[ -z "$TEARDOWN" || "$TEARDOWN" = "false" ]]; then
    plugin_resources=(
      [GITHUB_PLUGINS_CONFIGURED]=":"
      [GITLAB_PLUGINS_CONFIGURED]=":"
      [KUBERNETES_PLUGINS_CONFIGURED]="config_secrets_for_kubernetes_plugins"
      [ARGOCD_PLUGINS_CONFIGURED]=":"
      [AZURE_PLUGINS_CONFIGURED]=":"
      [JENKINS_PLUGINS_CONFIGURED]=":"
      [NOTIFICATIONS_PLUGINS_CONFIGURED]=":"
      [SONARQUBE_PLUGINS_CONFIGURED]=":"
      [OCM_PLUGINS_CONFIGURED]=":"
      [BULK_IMPORT_PLUGINS_CONFIGURED]=":"
      [TECHDOCS_PLUGINS_CONFIGURED]=":"
      [PAGERDUTY_PLUGINS_CONFIGURED]=":"
      [RBAC_PLUGINS_CONFIGURED]=":"
      [SERVICENOW_PLUGINS_CONFIGURED]=":"
      [TECHDOCS_CONTRIB_PLUGINS_CONFIGURED]=":"
      [THREESCALE_PLUGINS_CONFIGURED]=":"
      [KEYCLOAK_PLUGINS_CONFIGURED]="deploy_rhsso deploy_keycloak_resources config_secrets_for_keycloak_plugins create_users_and_groups_keycloak apply_keycloak_labels"
      [BITBUCKET_PLUGINS_CONFIGURED]=":"
      [DYNATRACE_PLUGINS_CONFIGURED]=":"
      [JIRA_PLUGINS_CONFIGURED]=":"
      [DATADOG_PLUGINS_CONFIGURED]=":"
      [TEKTON_PLUGINS_CONFIGURED]=":"
      [QUAY_PLUGINS_CONFIGURED]=":"
      [NEXUS_PLUGINS_CONFIGURED]=":"
      [ACR_PLUGINS_CONFIGURED]=":"
      [JFROG_PLUGINS_CONFIGURED]=":"
      [LIGHTHOUSE_PLUGINS_CONFIGURED]=":"
      [TECH_RADAR_PLUGINS_CONFIGURED]=":"
      [ANALYTICS_PLUGINS_CONFIGURED]=":"
      [MSGRAPH_PLUGINS_CONFIGURED]=":"
      [LDAP_PLUGINS_CONFIGURED]=":"
      [PINGIDENTITY_PLUGINS_CONFIGURED]=":"
    )
  else
    plugin_resources=(
      [GITHUB_PLUGINS_CONFIGURED]=":"
      [GITLAB_PLUGINS_CONFIGURED]=":"
      [KUBERNETES_PLUGINS_CONFIGURED]=":"
      [ARGOCD_PLUGINS_CONFIGURED]=":"
      [AZURE_PLUGINS_CONFIGURED]=":"
      [JENKINS_PLUGINS_CONFIGURED]=":"
      [NOTIFICATIONS_PLUGINS_CONFIGURED]=":"
      [SONARQUBE_PLUGINS_CONFIGURED]=":"
      [OCM_PLUGINS_CONFIGURED]=":"
      [BULK_IMPORT_PLUGINS_CONFIGURED]=":"
      [TECHDOCS_PLUGINS_CONFIGURED]=":"
      [PAGERDUTY_PLUGINS_CONFIGURED]=":"
      [RBAC_PLUGINS_CONFIGURED]=":"
      [SERVICENOW_PLUGINS_CONFIGURED]=":"
      [TECHDOCS_CONTRIB_PLUGINS_CONFIGURED]=":"
      [THREESCALE_PLUGINS_CONFIGURED]=":"
      [KEYCLOAK_PLUGINS_CONFIGURED]="uninstall_rhsso"
      [BITBUCKET_PLUGINS_CONFIGURED]=":"
      [DYNATRACE_PLUGINS_CONFIGURED]=":"
      [JIRA_PLUGINS_CONFIGURED]=":"
      [DATADOG_PLUGINS_CONFIGURED]=":"
      [TEKTON_PLUGINS_CONFIGURED]=":"
      [QUAY_PLUGINS_CONFIGURED]=":"
      [NEXUS_PLUGINS_CONFIGURED]=":"
      [ACR_PLUGINS_CONFIGURED]=":"
      [JFROG_PLUGINS_CONFIGURED]=":"
      [LIGHTHOUSE_PLUGINS_CONFIGURED]=":"
      [TECH_RADAR_PLUGINS_CONFIGURED]=":"
      [ANALYTICS_PLUGINS_CONFIGURED]=":"
      [MSGRAPH_PLUGINS_CONFIGURED]=":"
      [LDAP_PLUGINS_CONFIGURED]=":"
      [PINGIDENTITY_PLUGINS_CONFIGURED]=":"
    )
  fi
}

main() {
  source "${PWD}/env_variables.sh"
  source "${PWD}/.env"

  CONFIGMAP_FILE="${PWD}/resources/user-resources/dynamic-plugins-config.local.yaml"

  get_enabled_plugins

  set_enabled_plugins

  set_plugin_function_mappings

  # Determine enabled plugins
  enabled_plugins=()
  for env_var in "${!plugin_resources[@]}"; do
    if [[ "${!env_var}" == "true" ]]; then
      enabled_plugins+=("$env_var")
    fi
  done


  # Track current step index for each plugin
  declare -A current_step_index
  for env_var in "${enabled_plugins[@]}"; do
    current_step_index["$env_var"]=0
  done

  # Round-robin execution
  all_complete=false
  while [[ "$all_complete" == "false" ]]; do
    all_complete=true
    for env_var in "${enabled_plugins[@]}"; do
      steps=(${plugin_resources[$env_var]}) # Split steps into an array
      step_index=${current_step_index[$env_var]}

      if [[ $step_index -lt ${#steps[@]} ]]; then
        # Execute the current step
        ${steps[$step_index]}
        # Update to the next step
        current_step_index["$env_var"]=$((step_index + 1))
        all_complete=false
      fi
    done
  done

  echo "All plugins configured successfully."

  exit "${OVERALL_RESULT}"

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
