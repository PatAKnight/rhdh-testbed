# Plugin: `backstage-plugin-kubernetes` and `backstage-community-plugin-topology`

## Description

The `backstage-plugin-kubernetes` and `backstage-community-plugin-topology` plugins provide real-time visibility into Kubernetes resources related to your catalog entities. It enables developers to observe pod health, deployments, and other workload information directly from the entity page in RHDH.

---

## How to Configure

These plugins can be configured in two ways depending on your environment and needs:

### Manual Setup

Manually set up the plugin by:

1. Ensuring the Kubernetes cluster is reachable from your RHDH instance.
2. Creating a ServiceAccount and ClusterRoleBinding for Backstage access.
3. Mounting the kubeconfig or providing the necessary credentials.
4. Updating the app-config.yaml to enable the plugin.

App config example:

```YAML
kubernetes:
  serviceLocatorMethod:
    type: multiTenant
  clusterLocatorMethods:
    - type: config
      clusters:
        - name: ${K8S_CLUSTER_NAME}
          url: ${K8S_CLUSTER_URL}
          authProvider: serviceAccount
          serviceAccountToken: ${K8S_CLUSTER_TOKEN}
          caData: ${K8S_CA_DATA}
```

---

### Automatic Setup

You can use the root-level `start.sh` or run the specific integration script for this plugin.

#### Everything

The root script (`start.sh`) will:

- Install required Kubernetes RBAC resources
- Configure a `ServiceAccount` and bind it with the necessary roles
- Update the `rhdh-secrets` with token data

**Run:**

```bash
./start.sh
```

#### Just the Integration

At the moment, just running the specific plugin script will fail as it expects the resources needed (`ServiceAccount`, `Role`, `RoleBinding`) to already be present.

## Demo

After setup:

1. Visit the RHDH catalog.
2. Open a software entity that includes the `backstage.io/kubernetes-id` annotation.
   - If the Keycloak plugin was configured, the `rhsso-operator` entity could be used for demo purposes.
3. Navigate to either the Topology or Kubernetes tab.
4. You should see pod status, container logs, and deployment metrics

Demo users and entities may be created to simulate deployment environments if desired

## Related Files

- `resources/cluster-roles/`, `resources/service-accounts/` - contains Kubernetes RBAC YAMLs
- `scripts/configure-kubernetes-plugin.sh` - performs the automatic setup for Kubernetes integration
- `auth/cluster-secrets/` - Related secrets retrieved from the cluster
