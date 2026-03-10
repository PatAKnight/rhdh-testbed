# Round-Robin Execution Pattern - Implementation Guide

## Problem Statement

Plugin setup scripts can have long blocking waits, causing sequential execution to be very slow.

**Sequential Execution (SLOW - 10 minutes):**

```
NEXUS:  [Deploy Op] → [Wait 60s] → [Deploy Inst] → [Wait 90s] → [Config] (5 min)
ARGOCD:                                                                    [Deploy Op] → [Wait 60s] → [Deploy Inst] → [Wait 90s] → [Config] (5 min)
Total: 10 minutes
```

**Optimized Round-Robin (FAST - ~6 minutes):**

```
Step 1: NEXUS  [Deploy Op]              → ARGOCD [Deploy Op]
Step 2: NEXUS  [Wait 60s + Deploy Inst] → ARGOCD [Wait 60s + Deploy Inst]    (both waiting + acting!)
Step 3: NEXUS  [Wait 90s for Inst]      → ARGOCD [Wait 90s + Deploy Apps]    (both waiting + acting!)
Step 4: NEXUS  [Config Secrets]         → ARGOCD [Config Secrets]
Step 5: NEXUS  [Apply Labels]           → ARGOCD [Apply Labels]
Total: ~6 minutes (40% faster)
```

**Key Insight:** Combine waiting with the next action - never have a step that's just waiting!

---

## Solution: Combine Wait + Next Action

### Anti-Pattern ❌ (Idle Waiting)

```bash
# Separate wait and deploy = wasted round-robin turns
wait_for_operator() {
  # This function ONLY waits - no productive work
  while operator_not_ready; do sleep 5; done
}

deploy_instance() {
  # This function is quick - done in <1 second
  oc apply -f instance.yaml
}

# config-plugins.sh
CATEGORY_SETUP_FUNCTIONS=(
  [PLUGIN]="deploy_operator wait_for_operator deploy_instance"
)

# Round-robin execution with 2 plugins:
# Turn 1: Plugin A deploys operator (quick)
# Turn 2: Plugin B deploys operator (quick)
# Turn 3: Plugin A waits for operator (60s of idle waiting!)  ← WASTE
# Turn 4: Plugin B waits for operator (60s of idle waiting!)  ← WASTE
# Turn 5: Plugin A deploys instance (quick)
# Turn 6: Plugin B deploys instance (quick)
```

### Best Practice ✅ (Productive Waiting)

```bash
# Combine: wait for prerequisite, then immediately deploy next step
wait_for_operator_and_deploy_instance() {
  # Wait for prerequisite
  echo "Waiting for operator..."
  while operator_not_ready; do sleep 5; done

  # Immediately deploy next step when ready (no wasted time!)
  echo "Deploying instance..."
  oc apply -f instance.yaml
}

# config-plugins.sh
CATEGORY_SETUP_FUNCTIONS=(
  [PLUGIN]="deploy_operator wait_for_operator_and_deploy_instance"
)

# Round-robin execution with 2 plugins:
# Turn 1: Plugin A deploys operator (quick)
# Turn 2: Plugin B deploys operator (quick)
# Turn 3: Plugin A waits 60s + deploys instance  (productive!)  ✓
# Turn 4: Plugin B waits 60s + deploys instance  (productive!)  ✓
```

---

## Guidelines for Combining Functions

### 1. Combine Wait + Next Deployment

**Pattern:**

```bash
wait_for_X_and_deploy_Y() {
  # Wait for X to be ready
  wait_for_X_to_be_ready

  # Immediately deploy Y
  deploy_Y
}
```

**Examples:**

- `wait_for_operator_and_deploy_instance()`
- `wait_for_instance_and_deploy_applications()`
- `wait_for_database_and_run_migrations()`

### 2. Keep Pure Configuration Steps Separate

Don't combine wait steps with configuration/labeling:

```bash
# ✓ GOOD: Wait + deploy combined
wait_for_instance_and_deploy_apps() {
  wait_for_instance
  oc apply -f apps.yaml
}

# ✓ GOOD: Configuration is separate
config_secrets() {
  extract_credentials
  update_secrets_file
}

# ✗ BAD: Don't combine wait + config
wait_for_instance_and_config_secrets() {
  wait_for_instance
  extract_credentials # config doesn't depend on instance being ready
}
```

### 3. Final Step: Just Wait (If Needed)

If you have nothing to deploy after the last wait, just wait:

```bash
# Last step can be a pure wait if there's nothing to deploy after
wait_for_final_resource() {
  echo "Waiting for final resource..."
  while resource_not_ready; do sleep 5; done
}
```

---

## Real-World Example: ArgoCD Plugin

### Before (Suboptimal)

```bash
deploy_argocd() {
  oc apply -f operator.yaml
}

wait_for_operator() {
  while operator_not_ready; do sleep 5; done # Just waiting
}

deploy_instance() {
  oc apply -f instance.yaml # Quick action
}

wait_for_instance() {
  while instance_not_ready; do sleep 5; done # Just waiting
}

deploy_apps() {
  oc apply -f apps.yaml # Quick action
}

# 5 functions = 5 round-robin turns
# Turns 2 and 4 are idle waiting
```

### After (Optimized)

```bash
deploy_argocd() {
  oc apply -f operator.yaml
}

wait_for_operator_and_deploy_instance() {
  # Wait for operator
  while operator_not_ready; do sleep 5; done

  # Immediately deploy instance (no wasted turn!)
  oc apply -f instance.yaml
}

wait_for_instance_and_deploy_apps() {
  # Wait for instance
  while instance_not_ready; do sleep 5; done

  # Immediately deploy apps (no wasted turn!)
  oc apply -f apps.yaml
}

config_secrets() {
  # Config work
}

# 4 functions = 4 round-robin turns
# Every turn is productive!
```

### Full Implementation

```bash
#!/bin/bash

deploy_argocd() {
  echo "Deploying ArgoCD Operator..."
  oc apply -f $PWD/resources/operators/argocd-subscription.yaml --namespace=${NAMESPACE}
}

wait_for_argocd_operator_and_deploy_instance() {
  # Wait for operator to be ready
  echo "Waiting for ArgoCD operator to become ready..."
  SECONDS=0
  while true; do
    STATUS=$(oc get csv --namespace=${NAMESPACE} 2> /dev/null | grep argocd-operator | awk '{print $NF}')

    if [[ "$STATUS" == "Succeeded" ]]; then
      echo "ArgoCD operator is ready!"
      break
    fi

    if [[ $SECONDS -ge $TIMEOUT ]]; then
      echo "Timeout waiting for ArgoCD operator."
      exit 1
    fi

    sleep "$INTERVAL"
  done

  # Deploy ArgoCD instance (immediately after operator is ready)
  echo "Deploying ArgoCD instance..."
  oc apply -f $PWD/resources/argocd/argocd-instance.yaml --namespace=${NAMESPACE}
}

wait_for_argocd_instance_and_deploy_demo_applications() {
  # Wait for ArgoCD instance to be ready
  echo "Waiting for ArgoCD instance to be ready..."
  SECONDS=0
  while true; do
    ARGOCD_STATUS=$(oc get argocd argocd --namespace=${NAMESPACE} -o jsonpath='{.status.phase}' 2> /dev/null)

    if [[ "$ARGOCD_STATUS" == "Available" ]]; then
      echo "ArgoCD instance is ready!"
      break
    fi

    if [[ $SECONDS -ge $TIMEOUT ]]; then
      echo "Timeout waiting for ArgoCD instance."
      exit 1
    fi

    sleep "$INTERVAL"
  done

  # Deploy demo applications (immediately after instance is ready)
  echo "Deploying demo ArgoCD applications..."
  oc apply -f $PWD/resources/argocd/demo-applications.yaml --namespace=${NAMESPACE}
}

config_secrets_for_argocd_plugins() {
  echo "Configuring secrets..."
  # Extract credentials and update secrets
}

apply_argocd_labels() {
  echo "Applying labels..."
  # Label resources for Backstage
}

register_argocd_demo_catalog_entities() {
  echo "Registering catalog entities..."
  # Register demo entities
}
```

### config-plugins.sh

```bash
declare -A CATEGORY_SETUP_FUNCTIONS=(
  [ARGOCD]="deploy_argocd wait_for_argocd_operator_and_deploy_instance wait_for_argocd_instance_and_deploy_demo_applications config_secrets_for_argocd_plugins apply_argocd_labels register_argocd_demo_catalog_entities"
)
```

---

## Execution Flow Comparison

### With 2 Plugins: Nexus + ArgoCD

**Before (6 steps each = 12 turns):**

```
Turn 1:  NEXUS  deploy_nexus
Turn 2:  ARGOCD deploy_argocd
Turn 3:  NEXUS  wait_for_nexus_operator        (idle - 60s)
Turn 4:  ARGOCD wait_for_argocd_operator       (idle - 60s)
Turn 5:  NEXUS  deploy_nexus_instance
Turn 6:  ARGOCD deploy_argocd_instance
Turn 7:  NEXUS  wait_for_nexus_instance        (idle - 90s)
Turn 8:  ARGOCD wait_for_argocd_instance       (idle - 90s)
Turn 9:  NEXUS  config_secrets
Turn 10: ARGOCD config_secrets
Turn 11: NEXUS  apply_labels
Turn 12: ARGOCD apply_labels
```

**After (4-5 steps each = 8-10 turns):**

```
Turn 1: NEXUS  deploy_nexus
Turn 2: ARGOCD deploy_argocd
Turn 3: NEXUS  wait_for_nexus_operator + deploy_instance    (productive - 60s)
Turn 4: ARGOCD wait_for_argocd_operator + deploy_instance   (productive - 60s)
Turn 5: NEXUS  wait_for_nexus_instance                      (90s)
Turn 6: ARGOCD wait_for_argocd_instance + deploy_apps       (productive - 90s)
Turn 7: NEXUS  config_secrets
Turn 8: ARGOCD config_secrets
Turn 9: NEXUS  apply_labels
Turn 10: ARGOCD apply_labels
```

**Result:** Fewer turns, more productive work per turn!

---

## Decision Tree: When to Combine

```
Does the next step depend on this wait completing?
│
├─ YES: Can it be deployed immediately after?
│  │
│  ├─ YES → Combine them! ✓
│  │       Example: wait_for_operator_and_deploy_instance
│  │
│  └─ NO → Keep separate
│         Example: wait_for_instance + config_secrets
│                  (config doesn't need to wait for instance)
│
└─ NO → Keep separate
        Example: apply_labels + populate_demo_data
                (demo data doesn't depend on labels)
```

---

## Benefits

1. **Reduced Idle Time**: Every round-robin turn does useful work
2. **Fewer Turns**: Combining functions reduces total turn count
3. **Better UX**: Faster overall setup time
4. **Efficient Parallelism**: Multiple plugins make progress simultaneously

---

## Time Savings

**Example: 2 plugins, each with 60s + 90s waits**

| Approach               | Nexus Time | ArgoCD Time         | Total Time | Savings |
| ---------------------- | ---------- | ------------------- | ---------- | ------- |
| Sequential             | 5 min      | 5 min (after Nexus) | 10 min     | 0%      |
| Round-robin (separate) | 5 min      | 5 min (parallel)    | ~5 min     | 50%     |
| Round-robin (combined) | ~4 min     | ~4 min (parallel)   | ~4 min     | 60%     |

---

## Checklist for New Plugins

- [ ] Identify all wait operations
- [ ] For each wait, ask: "What should I deploy next?"
- [ ] Combine wait + next deployment into one function
- [ ] Keep configuration/labeling steps separate
- [ ] Name combined functions: `wait_for_X_and_deploy_Y`
- [ ] List functions in dependency order in `CATEGORY_SETUP_FUNCTIONS`
- [ ] Test with another plugin to verify efficiency

---

## Testing

Add timing to see the improvement:

```bash
deploy_plugin() {
  echo "[PLUGIN - $(date +%H:%M:%S)] Deploying operator..."
  oc apply -f operator.yaml
}

wait_for_plugin_operator_and_deploy_instance() {
  echo "[PLUGIN - $(date +%H:%M:%S)] Waiting for operator..."
  # wait logic
  echo "[PLUGIN - $(date +%H:%M:%S)] Operator ready, deploying instance..."
  oc apply -f instance.yaml
}

# Output shows:
# [NEXUS - 10:00:00] Deploying operator...
# [ARGOCD - 10:00:01] Deploying operator...
# [NEXUS - 10:00:02] Waiting for operator...
# [ARGOCD - 10:00:03] Waiting for operator...
# [NEXUS - 10:01:02] Operator ready, deploying instance...  (1 minute later)
# [ARGOCD - 10:01:03] Operator ready, deploying instance... (parallel!)
```

---

## Summary

**Key Principle:** Make every round-robin turn productive by combining wait operations with their
dependent deployments.

**Pattern:**

```bash
wait_for_prerequisite_and_deploy_dependent() {
  wait_for_prerequisite_to_be_ready
  immediately_deploy_dependent_resource
}
```

This ensures maximum parallelism and minimum idle time!
