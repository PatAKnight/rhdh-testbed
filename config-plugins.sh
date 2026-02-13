#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
for file in ${DIR}/scripts/*.sh; do source $file; done

# =============================================================================
# Plugin Detection by Package Pattern
# =============================================================================
# Maps package name patterns to the category of setup required.
# When a user enables a plugin in dynamic-plugins-configmap.yaml,
# we detect it here and run the appropriate cluster setup.
#
# Format: [pattern]="category"
# Patterns use grep -E regex syntax
# =============================================================================

declare -A PACKAGE_TO_CATEGORY=(
  #Keycloak - requires RHSSO operator deployment
  ["plugin-catalog-backend-module-keycloak-dynamic"]="KEYCLOAK"

  # Tekton - requires OpenShift Pipelines Operator deployment
  ["plugin-tekton"]="TEKTON"

  # OCM - requires Advanced Cluster Management Operator deployment
  ["plugin-ocm-backend"]="OCM"
  ["plugin-ocm$"]="OCM"

  # 3scale - requires 3scale operator deployment
  ["plugin-3scale-backend"]="3SCALE"

  # Nexus Repository Manager - requires Nexus operator deployment
  ["plugin-nexus-repository-manager"]="NEXUS"

  #Kubernetes - needs ServiceAccount token setup
  ["plugin-kubernetes-backend"]="KUBERNETES"
  ["plugin-kubernetes"]="KUBERNETES"
  ["plugin-topology"]="KUBERNETES"
)

# =============================================================================
# Setup/Teardown Functions for Each Category
# =============================================================================

declare -A CATEGORY_SETUP_FUNCTIONS=(
  [KEYCLOAK]="deploy_rhsso deploy_keycloak_resources config_secrets_for_keycloak_plugins create_users_and_groups_keycloak apply_keycloak_labels"
  [TEKTON]="deploy_tekon deploy_pipelines apply_tekton_labels"
  [OCM]="deploy_acm config_secrets_for_ocm_plugins deploy_multicluster_hub apply_ocm_labels"
  [3SCALE]="copy_3scale_files deploy_3scale deploy_minio deploy_3scale_resources"
  [NEXUS]="deploy_nexus deploy_nexus_resources config_secrets_for_nexus_plugins apply_nexus_labels populate_nexus_demo_data register_nexus_demo_catalog_entities"
  [KUBERNETES]="config_secrets_for_kubernetes_plugins"
)

declare -A CATEGORY_TEARDOWN_FUNCTIONS=(
  [KEYCLOAK]="uninstall_rhsso"
  [TEKTON]="uninstall_tekton"
  [OCM]="uninstall_acm"
  [3SCALE]="uninstall_3scale"
  [NEXUS]="uninstall_nexus"
  [KUBERNETES]=":"
)

# =============================================================================
# Parse dynamic-plugins-configmap.yaml for enabled plugins
# =============================================================================

get_enabled_plugins_from_config() {
  local config_file="$1"
  local enabled_packages=()

  if [[ ! -f "$config_file" ]]; then
    echo "WARNING: dynamic-plugins-configmap.yaml not found at $config_file"
    return 1
  fi

  echo "Parsing dynamic plugins configuration: $config_file"
  echo ""

  # Extract enabled plugins (disabled: false)
  # This handles the YAML structure where each plugin block has:
  #   -package: <path>
  #    disabled: true/false
  # We use awk to find package lines followed by "disabled: false"

  local in_plugin_block=false
  local current_package=""

  while IFS= read -r line; do
    #Check for package line
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*package:[[:space:]]*(.*)$ ]]; then
      current_package="${BASH_REMATCH[1]}"
      in_plugin_block=true
    # Check for disabled line within a plugin block
    elif [[ "$in_plugin_block" == true && "$line" =~ ^[[:space:]]*disabled:[[:space:]]*(.+)$ ]]; then
      local disabled_value="${BASH_REMATCH[1]}"
      # Remove quotes if present
      disabled_value="${disabled_value//\"/}"
      disabled_value="${disabled_value//\'/}"

      if [[ "$disabled_value" == "false" ]]; then
        enabled_packages+=("$current_package")
      fi
    # Reset if we hit another list item or non-indented line
    elif [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]] || [[ ! "$line" =~ ^[[:space:]] ]]; then
      in_plugin_block=false
    fi
  done < "$config_file"

  ENABLED_PACKAGES=("${enabled_packages[@]}")
}

# =============================================================================
# Determine which categories need setup based on enabled packages
# =============================================================================

detect_required_categories() {
  local -A categories_needed=()
  
  for package in "${ENABLED_PACKAGES[@]}"; do
    for pattern in "${!PACKAGE_TO_CATEGORY[@]}"; do
      if echo "$package" | grep -qE "$pattern"; then
        local category="${PACKAGE_TO_CATEGORY[$pattern]}"
        if [[ -z "${categories_needed[$category]:-}" ]]; then
          categories_needed["$category"]=1
          echo "  ✓ Detected: $category (matched: $package)"
        fi
      fi
    done
  done
  
  ENABLED_CATEGORIES=("${!categories_needed[@]}")
}

# =============================================================================
# Execute setup or teardown functions
# =============================================================================

execute_category_functions() {
  local function_map_name="$1"
  declare -n function_map="$function_map_name"
  
  if [[ ${#ENABLED_CATEGORIES[@]} -eq 0 ]]; then
    echo "No plugins requiring cluster resources detected."
    return 0
  fi
  
  # Track current step for round-robin execution
  declare -A current_step_index
  for category in "${ENABLED_CATEGORIES[@]}"; do
    current_step_index["$category"]=0
  done

  # Round-robin execution
  local all_complete=false
  while [[ "$all_complete" == "false" ]]; do
    all_complete=true
    for category in "${ENABLED_CATEGORIES[@]}"; do
      local functions="${function_map[$category]}"
      local steps=($functions)
      local step_index=${current_step_index[$category]}

      if [[ $step_index -lt ${#steps[@]} ]]; then
        local step="${steps[$step_index]}"
        if [[ "$step" != ":" ]]; then
          echo ""
          echo "[$category] Executing: $step"
          $step
        fi
        current_step_index["$category"]=$((step_index + 1))
        all_complete=false
      fi
    done
  done
}

# =============================================================================
# Main Entry Point
# =============================================================================
main() {
  # Source configuration
  if [[ -f "${DIR}/env_variables.sh" ]]; then
    source "${DIR}/env_variables.sh"
  fi
  if [[ -f "${DIR}/.env" ]]; then
    source "${DIR}/.env"
  fi

  # Determine config file path
  local config_file="${CONFIGMAP_FILE:-${DIR}/resources/user-resources/dynamic-plugins-configmap.local.yaml}"

  echo ""
  echo "=============================================="
  echo "Plugin Configuration"
  echo "=============================================="
  
  # Parse the dynamic plugins config
  get_enabled_plugins_from_config "$config_file"
  
  if [[ ${#ENABLED_PACKAGES[@]} -eq 0 ]]; then
    echo "No enabled plugins found in config."
    return 0
  fi
  
  echo ""
  echo "Detecting plugins requiring cluster resources..."
  detect_required_categories
  
  echo ""
  echo "Categories requiring setup: ${ENABLED_CATEGORIES[*]:-none}"
  echo ""

  # Execute setup or teardown
  if [[ "${TEARDOWN:-false}" == "true" ]]; then
    echo "Running teardown functions..."
    execute_category_functions "CATEGORY_TEARDOWN_FUNCTIONS"
  else
    echo "Running setup functions..."
    execute_category_functions "CATEGORY_SETUP_FUNCTIONS"
  fi

  echo ""
  echo "=============================================="
  echo "Plugin configuration complete."
  echo "=============================================="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
