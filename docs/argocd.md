# Plugin: ArgoCD Plugins

## Description

The ArgoCD plugins integrate Argo CD with Red Hat Developer Hub (RHDH), enabling developers to view
GitOps deployment information, application health status, and sync history directly within the
Backstage catalog.

**Four ArgoCD Plugins Available:**

1. **@roadiehq/backstage-plugin-argo-cd** (frontend) - RoadieHQ frontend plugin
2. **@roadiehq/backstage-plugin-argo-cd-backend** (backend) - RoadieHQ backend plugin
3. **@backstage-community/plugin-argocd** (frontend) - Backstage Community frontend plugin
4. **@backstage-community/plugin-argocd-backend** (backend) - Backstage Community backend plugin

**IMPORTANT: Plugin Selection Strategy**

Enable **both plugins from the same source** and ensure the other two are disabled. Each pair is a
complete, self-contained integration:

- **Option A:** Enable both Backstage Community ArgoCD plugins:
  - `@backstage-community/plugin-argocd`
  - `@backstage-community/plugin-argocd-backend`

- **Option B:** Enable both RoadieHQ ArgoCD plugins:
  - `@roadiehq/backstage-plugin-argo-cd`
  - `@roadiehq/backstage-plugin-argo-cd-backend`

**DO NOT mix plugins from different sources** (e.g., RoadieHQ frontend with Backstage Community
backend), as they might have different annotation requirements and configuration patterns.

### Key Features

- Real-time application sync and health status
- Deployment history and rollback information
- Multi-instance ArgoCD support
- GitOps workflow visibility
- Pod and resource status tracking
- Deep-linking to ArgoCD UI

---

## How to Configure

You can configure these plugins either manually or automatically using the provided scripts.

### Manual Setup

1. Deploy required infrastructure:
   - Install the ArgoCD Operator (community operator).
   - Deploy an `ArgoCD` custom resource to create an ArgoCD instance.
   - Wait for the ArgoCD instance to be ready and obtain the URL and credentials.

2. Configure RHDH integration:
   - Choose **one** plugin pair (both from the same source).
   - Enable the selected plugins in your dynamic plugins configuration.
   - Add the appropriate configuration to your `app-config.yaml`:

#### For Backstage Community Plugins

```yaml
argocd:
  # Single instance
  appLocatorMethods:
    - type: "config"
      instances:
        - name: argoInstance
          url: ${ARGOCD_URL}
          token: ${ARGOCD_AUTH_TOKEN}
```

#### For RoadieHQ Plugins

```yaml
argocd:
  # Single instance
  appLocatorMethods:
    - type: "config"
      instances:
        - name: argoInstance
          url: ${ARGOCD_URL}
          username: ${ARGOCD_USERNAME}
          password: ${ARGOCD_PASSWORD}
```

3. Configure authentication:
   - Add to your secrets:

     ```yaml
     ARGOCD_URL: "https://argocd-server-route.example.com"
     ARGOCD_AUTH_TOKEN: "<your-token>" # For Backstage Community plugins
     ARGOCD_USERNAME: "admin" # For RoadieHQ plugins
     ARGOCD_PASSWORD: "<your-password>" # For RoadieHQ plugins
     ```

4. Add annotations to catalog entities:

#### For Backstage Community Plugins

Add the following annotations to your component's `catalog-info.yaml`:

```yaml
metadata:
  annotations:
    # Label selector for applications
    argocd/app-selector: "rht-gitops.com/my-app=my-value"

    # Optional: specify ArgoCD instance (if using multiple instances)
    argocd/instance-name: "argoInstance"
```

#### For RoadieHQ Plugins

Add the following annotations to your component's `catalog-info.yaml`:

```yaml
metadata:
  annotations:
    # For a single ArgoCD application
    argocd/app-name: my-app-name

    # OR for multiple applications using label selector
    argocd/app-selector: app.kubernetes.io/name=my-app
```

---

### Automatic Setup

Automated setup is available in two levels depending on how much you want configured for you.

#### Everything

Runs the root-level script to deploy the complete infrastructure including ArgoCD. Requires the
ArgoCD plugins to be enabled by setting `disabled: false` in your dynamic plugins configuration.

**Run:**

```bash
./start.sh
```

#### Just the Integration

Only configures the integration resources for this plugin. Use this if you already have a Backstage
instance running and just need this plugin.

**Run:**

```bash
./scripts/config-argocd-plugin.sh
```

This script will:

- Install the ArgoCD Operator
- Deploy an ArgoCD instance with OpenShift OAuth integration
- Configure secrets for RHDH authentication (`ARGOCD_URL`, `ARGOCD_USERNAME`, `ARGOCD_PASSWORD`,
  `ARGOCD_AUTH_TOKEN`)
- Apply Kubernetes labels for topology view
- Deploy demo ArgoCD applications (guestbook, helm, kustomize)
- Register demo catalog entities

**Important - Manual Configuration Required:**

After running the script, you must add the ArgoCD configuration to your `app-config.yaml` based on
which plugins you choose to use. See the configuration examples in the Manual Setup section above.

---

## Demo

1. Go to your RHDH instance.
2. Navigate to the Catalog.
3. Open a component that has ArgoCD annotations:
   - `demo-guestbook-app` (`argocd/app-name` annotation style)
   - `demo-helm-app` (`argocd/app-selector` annotation style)
   - `demo-kustomize-app` (both annotation styles)
4. Look for the "ArgoCD" tab or card.
5. View the application sync status, health, deployment history, and pod information.

Alternatively:

1. Access the ArgoCD web UI directly at the route created in your namespace.
2. Login with admin credentials (password stored in secrets).
3. Browse the applications and verify demo apps are deployed.

---

## Demo Data

This plugin includes test resources to demonstrate functionality:

### Demo Applications

- **demo-guestbook-app**: Classic Argo CD guestbook demo application using plain Kubernetes
  manifests
- **demo-helm-app**: Helm-based guestbook application showcasing Helm chart deployments
- **demo-kustomize-app**: Kustomize-based application demonstrating Kustomize overlays

All demo applications use public GitHub repositories from the official ArgoCD examples:

- Repository: https://github.com/argoproj/argocd-example-apps
- Applications are deployed to the `rhdh` namespace
- Labeled with `rht-gitops.com/demo-argocd` for discovery

### Demo Catalog Entities

The setup automatically registers demo components in the RHDH catalog:

- **demo-guestbook-app** (Component) - Demonstrates `argocd/app-name` annotation style
  - Annotation: `argocd/app-name: demo-guestbook-app`
  - Owner: `group:default/guardians-of-the-galaxy`
  - Purpose: Shows single-application annotation style

- **demo-helm-app** (Component) - Demonstrates `argocd/app-selector` annotation style
  - Annotation: `argocd/app-selector: rht-gitops.com/demo-argocd=helm-app`
  - Owner: `group:default/x-men`
  - Purpose: Shows label selector annotation style

- **demo-kustomize-app** (Component) - Demonstrates both annotation styles
  - Annotations: Both `argocd/app-name` and `argocd/app-selector`
  - Owner: `group:default/avengers`
  - Purpose: Demonstrates compatibility with both annotation styles for comparison

These catalog entities use existing Keycloak teams for ownership, enabling RBAC testing. Different
users will see different components based on their team membership.

### Configuration

Demo data is automatically populated during setup. To disable:

```bash
export POPULATE_DEMO_DATA=false
./scripts/config-argocd-plugin.sh
```

To manually register catalog entities:

```bash
oc create configmap argocd-demo-entities-config-map \
  --from-file=demo-argocd-applications.yaml=resources/argocd/demo-catalog-entities.yaml \
  -n rhdh

oc label configmap argocd-demo-entities-config-map \
  backstage.io/kubernetes-id=developer-hub -n rhdh
```

---

## Accessing ArgoCD

### Web UI

Get the ArgoCD URL and login:

```bash
# Get the URL
echo "https://$(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')"

# Get admin password
oc get secret argocd-cluster -n rhdh -o jsonpath='{.data.admin\.password}' | base64 -d
echo ""
```

Default username: `admin`

### CLI

Install the ArgoCD CLI and login:

```bash
# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
ARGOCD_URL=$(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')
ARGOCD_PASS=$(oc get secret argocd-cluster -n rhdh -o jsonpath='{.data.admin\.password}' | base64 -d)

argocd login $ARGOCD_URL --username admin --password $ARGOCD_PASS --insecure

# List applications
argocd app list
```

---

## Quick Verification

After deployment, verify everything is working:

```bash
# 1. Check operator is installed
oc get csv -n rhdh | grep argocd-operator

# 2. Check ArgoCD instance is running
oc get argocd argocd -n rhdh

# 3. Check ArgoCD server is available
oc get route argocd-server -n rhdh

# 4. Check demo applications are deployed
oc get application -n rhdh

# 5. Check catalog entities are registered
oc get configmap argocd-demo-entities-config-map -n rhdh

# 6. Verify applications in ArgoCD
ARGOCD_URL=$(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')
curl -k https://${ARGOCD_URL}/api/v1/applications
```

---

## Troubleshooting

For detailed troubleshooting procedures, see the comprehensive guides:

- **[ArgoCD Troubleshooting Guide](../guides/argocd-troubleshooting.md)** - Diagnose and fix common
  issues:
  - Operator installation problems
  - ArgoCD instance startup issues
  - Application sync failures
  - Plugin integration problems (annotation styles, multiple plugin sets)
  - Authentication and RBAC issues
  - Network connectivity
  - Performance issues
  - Complete error message reference

### Quick Troubleshooting Tips

**Applications Not Syncing:**

```bash
# Check application status
oc get application -n rhdh

# Check ArgoCD server logs
oc logs -n rhdh deployment/argocd-server

# Check application controller logs
oc logs -n rhdh deployment/argocd-application-controller
```

**Plugin Not Showing Applications:**

1. Verify you're using the correct annotation style for your plugin choice
2. Verify ArgoCD configuration in `app-config.yaml`
3. Check RHDH backend logs:
   `oc logs -n rhdh deployment/backstage -c backstage-backend | grep -i argocd`

**Authentication Issues:**

```bash
# Verify credentials
oc get secret argocd-cluster -n rhdh -o jsonpath='{.data.admin\.password}' | base64 -d

# Test ArgoCD API manually
ARGOCD_URL=$(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')
ARGOCD_PASS=$(oc get secret argocd-cluster -n rhdh -o jsonpath='{.data.admin\.password}' | base64 -d)
curl -k https://${ARGOCD_URL}/api/v1/session -d '{"username":"admin","password":"'$ARGOCD_PASS'"}'
```

For complete troubleshooting procedures, diagnostics, and solutions, see the
[Troubleshooting Guide](../guides/argocd-troubleshooting.md).

---

## Production Configuration

For production deployments, see the comprehensive guides:

- **[ArgoCD Advanced Configuration Guide](../guides/argocd-advanced-config.md)** - Production-ready
  setups:
  - High availability configuration
  - Resource tuning and sizing guidelines
  - Multiple ArgoCD instance support
  - Security configuration (RBAC, SSO, TLS/SSL)
  - Git repository configuration (private repos, SSH keys)
  - ApplicationSets for application templating
  - Custom health checks
  - Notifications and webhooks
  - Backup and restore procedures
  - Monitoring and metrics (Prometheus, Grafana)
  - Performance optimization

---

## Related Files

- `/scripts/config-argocd-plugin.sh` - Automates plugin setup
- `/resources/argocd/` - ArgoCD CRs and supporting manifests
- `/resources/argocd/argocd-instance.yaml` - ArgoCD instance definition
- `/resources/argocd/demo-applications.yaml` - Demo ArgoCD applications
- `/resources/argocd/demo-catalog-entities.yaml` - Demo catalog entities with ArgoCD annotations
- `/resources/operators/argocd-subscription.yaml` - ArgoCD operator subscription

---

## Additional Resources

For more detailed information:

- **[ArgoCD Troubleshooting Guide](../guides/argocd-troubleshooting.md)** - Complete troubleshooting
  procedures
- **[ArgoCD Advanced Configuration](../guides/argocd-advanced-config.md)** - Production-ready
  configurations
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Backstage Community ArgoCD Plugin](https://github.com/backstage/community-plugins/tree/main/workspaces/argocd)
- [RoadieHQ ArgoCD Plugin](https://github.com/RoadieHQ/roadie-backstage-plugins/tree/main/plugins/backstage-plugin-argo-cd)
- [ArgoCD Operator Documentation](https://argocd-operator.readthedocs.io/)

---

## Notes

- The ArgoCD Operator is a community operator and is available in the OperatorHub.
- The default installation uses OpenShift OAuth for SSO integration.
- Initial admin password can be retrieved from the `argocd-cluster` secret.
- The ArgoCD instance is configured with resource limits suitable for demo/testing.
- For production use, adjust resource limits and enable HA mode in the ArgoCD CR.
- Demo applications use public GitHub repositories and do not require Git credentials.
