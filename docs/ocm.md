# Plugin: `backstage-community-plugin-ocm`

## Description

The `backstage-community-plugin-ocm` plugin integrates Red Hat Advanced Cluster Management (ACM) data into RHDH. It displays cluster inventory and status directly on the Backstage entity page, helping users quickly assess the state of managed OpenShift clusters.

---

## How to Configure

You can set up this plugin either manually or using the automation scripts provided.

### Manual Setup

Steps to configure the plugin manually:

1. Install the ACM Operator into your OpenShift cluster if not already present.
2. Ensure ACM is managing at least one OpenShift cluster.
3. Configure your RHDH instance with access to the ACM `Multiclusterhub` API and any required credentials.
4. Add the plugin to the dynamic plugin config.
5. Update the app config to point to the ACM APIs and define how cluster data is surfaced.

Example app config segment:

```YAML
catalog:
  providers:
    ocm:
      env:
        name: ${OCM_HUB_NAME}
        url: ${OCM_HUB_URL}
        serviceAccountToken: ${OCM_SA_TOKEN}
```

---

### Automatic Setup

You can use either the root `start.sh` script for full setup or the plugin-specific script for targeted integration

#### Everything

Running `start.sh` will:

- Install the ACM operator and wait for it to be ready
- Deploy a `ServiceAccount` and bind it to the necessary cluster roles
- Deploy the `MultiClusterHub` CR
- Update `rhdh-secrets` with ACM access credentials

**Run:**

```bash
./start.sh
```

#### Just the Integration

Running `scripts/config-ocm-plugins.sh` will:

- Ensure the ACM operator is installed
- Deploy the `MultiClusterHub` CR

**Run:**

```bash
scripts/config-ocm-plugins.sh
```

## Demo

Once installed:

1. Navigate to the RHDH catalog.
2. Open an entity representing a cluster (with appropriate annotations).
3. The OCM tab will appear if the plugin is configured correctly.
4. You should see information like cluster status, distribution, Kubernetes version, and compliance.

Demo verification:

- Confirm the presence of cluster names like local-cluster in the plugin panel
- Validate that status indicators (e.g., healthy, degraded) are correctly shown

## Related Files

- `resources/ocm/` - ACM specific Kubernetes manifests (e.g., MultiClusterHub)
- `scripts/config-ocm-plugins.sh` - performs the automatic setup for ACM integration
- `auth/cluster-secrets/` - Related secrets retrieved from the cluster
- `resources/operators/` - Subscription for the ACM operator
