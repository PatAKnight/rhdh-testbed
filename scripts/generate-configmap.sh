#!/bin/bash
#
# Generate ConfigMap from dynamic-plugins.default.yaml
#
# Usage: ./scripts/generate-configmap.sh [namespace]
#
# This script converts the upstream dynamic-plugins.default.yaml
# into a Kubernetes ConfigMap that can be applied to the cluster.
#
generate_configmap() {
  set -euo pipefail

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
  NAMESPACE="${1:-}"

  INPUT_FILE="$PROJECT_ROOT/resources/rhdh/dynamic-plugins.default.yaml"
  OUTPUT_FILE="$PROJECT_ROOT/resources/rhdh/dynamic-plugins-configmap.yaml"

  # Validate input file exists
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "ERROR: Input file not found: $INPUT_FILE"
    echo ""
    echo "Make sure dynamic-plugins.default.yaml exists in resources/rhdh/"
    echo "You can sync it from upstream by running:"
    echo "  curl -sL https://raw.githubusercontent.com/redhat-developer/rhdh/main/dynamic-plugins.default.yaml \\"
    echo "    -o resources/rhdh/dynamic-plugins.default.yaml"
    exit 1
  fi

  # Generate ConfigMap header
  cat > "$OUTPUT_FILE" << 'EOF'
# AUTO-GENERATED - Do not edit directly
# Source: dynamic-plugins.default.yaml from upstream RHDH
# To regenerate: ./scripts/generate-configmap.sh
#
# This ConfigMap is applied to the cluster and consumed by RHDH
# for dynamic plugin configuration.
kind: ConfigMap
apiVersion: v1
metadata:
  name: rhdh-dynamic-plugins
EOF

  # Add namespace if provided
  if [[ -n "$NAMESPACE" ]]; then
    echo "  namespace: $NAMESPACE" >> "$OUTPUT_FILE"
  fi

  cat >> "$OUTPUT_FILE" << 'EOF'
  labels:
    backstage.io/kubernetes-id: developer-hub
data:
  dynamic-plugins.yaml: |
EOF

  # Indent the YAML content (6 spaces for ConfigMap data block) and Remove leading spaces only from comment lines before 'plugins:'
  awk '
    /^[[:space:]]*plugins:/ { found=1 }
    !found && /^[[:space:]]*#/ { sub(/^[[:space:]]+/, "") }
    { print "    " $0 }
  ' "$INPUT_FILE" >> "$OUTPUT_FILE"

  # Summary
  PLUGIN_COUNT=$(grep -c "^- package:" "$INPUT_FILE" 2>/dev/null || echo "0")
  echo "Generated: $OUTPUT_FILE"
  echo "  - Plugins: $PLUGIN_COUNT entries"
  if [[ -n "$NAMESPACE" ]]; then
    echo "  - Namespace: $NAMESPACE"
  else
    echo "  - Namespace: (not set - will use default or kubectl context)"
  fi
}

# Only run if executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  generate_configmap "$@"
fi
