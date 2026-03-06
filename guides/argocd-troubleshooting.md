# ArgoCD - Troubleshooting Guide

This guide helps you diagnose and fix common issues with the ArgoCD plugins for RHDH.

---

## Table of Contents

- [Operator Issues](#operator-issues)
- [ArgoCD Instance Issues](#argocd-instance-issues)
- [Application Sync Issues](#application-sync-issues)
- [Plugin Integration Issues](#plugin-integration-issues)
- [Authentication and Authorization](#authentication-and-authorization)
- [Network and Connectivity](#network-and-connectivity)
- [Performance Issues](#performance-issues)
- [Common Error Messages](#common-error-messages)

---

## Operator Issues

### Operator Not Installing

**Symptoms:**

- Subscription exists but CSV never appears
- Install plan is stuck in "Installing" state

**Diagnosis:**

```bash
# Check subscription status
oc get subscription argocd-operator-subscription -n rhdh -o yaml

# Check install plan
oc get installplan -n rhdh

# Check for operator pod issues
oc get pods -n openshift-marketplace | grep community-operators
```

**Solutions:**

1. **Verify operator catalog is healthy:**

   ```bash
   oc get catalogsource -n openshift-marketplace
   oc get pods -n openshift-marketplace
   ```

2. **Delete and recreate the subscription:**

   ```bash
   oc delete subscription argocd-operator-subscription -n rhdh
   oc apply -f resources/operators/argocd-subscription.yaml -n rhdh
   ```

3. **Check operator pod logs:**

   ```bash
   oc logs -n openshift-marketplace \
     $(oc get pods -n openshift-marketplace -l olm.catalogSource=community-operators -o name | head -n1)
   ```

### Operator CSV in Failed State

**Symptoms:**

- CSV shows "Failed" phase
- Operator pod is crash looping

**Diagnosis:**

```bash
# Check CSV status
oc get csv -n rhdh | grep argocd-operator

# Check operator pod logs
oc logs -n rhdh deployment/argocd-operator-controller-manager
```

**Solutions:**

1. **Check for resource conflicts:**

   ```bash
   # Look for existing ArgoCD CRDs from other installations
   oc get crd | grep argocd
   ```

2. **Delete and reinstall the operator:**

   ```bash
   ./scripts/config-argocd-plugin.sh
   # Or manually:
   OPERATOR=$(oc get csv -n rhdh | grep argocd-operator | awk '{print $1}')
   oc delete csv $OPERATOR -n rhdh
   oc delete subscription argocd-operator-subscription -n rhdh
   oc apply -f resources/operators/argocd-subscription.yaml -n rhdh
   ```

---

## ArgoCD Instance Issues

### ArgoCD Instance Stuck in Pending

**Symptoms:**

- `oc get argocd argocd -n rhdh` shows status as empty or "Pending"
- ArgoCD server pod not starting

**Diagnosis:**

```bash
# Check ArgoCD CR status
oc get argocd argocd -n rhdh -o yaml

# Check events
oc get events -n rhdh --sort-by='.lastTimestamp' | grep -i argocd

# Check pod status
oc get pods -n rhdh | grep argocd
```

**Solutions:**

1. **Check for resource constraints:**

   ```bash
   # Check if pods are pending due to resources
   oc describe pod -n rhdh -l app.kubernetes.io/name=argocd-server
   ```

2. **Reduce resource requirements (for testing):**

   Edit `resources/argocd/argocd-instance.yaml` and reduce resource requests:

   ```yaml
   spec:
     controller:
       resources:
         requests:
           cpu: 100m
           memory: 512Mi
   ```

   Then reapply:

   ```bash
   oc apply -f resources/argocd/argocd-instance.yaml -n rhdh
   ```

### ArgoCD Server Not Accessible

**Symptoms:**

- Route exists but returns 503 or connection refused
- ArgoCD UI not loading

**Diagnosis:**

```bash
# Check route
oc get route argocd-server -n rhdh

# Check server pod
oc get pods -n rhdh -l app.kubernetes.io/name=argocd-server

# Check server logs
oc logs -n rhdh deployment/argocd-server
```

**Solutions:**

1. **Verify server pod is running:**

   ```bash
   oc get pods -n rhdh -l app.kubernetes.io/name=argocd-server
   ```

2. **Check for TLS configuration issues:**

   ```bash
   # Verify route TLS settings
   oc get route argocd-server -n rhdh -o yaml | grep -A5 tls
   ```

3. **Restart ArgoCD server:**

   ```bash
   oc delete pod -n rhdh -l app.kubernetes.io/name=argocd-server
   ```

### Dex/SSO Integration Issues

**Symptoms:**

- Cannot login with OpenShift credentials
- Dex pod crash looping

**Diagnosis:**

```bash
# Check Dex pod
oc get pods -n rhdh -l app.kubernetes.io/name=argocd-dex-server

# Check Dex logs
oc logs -n rhdh deployment/argocd-dex-server
```

**Solutions:**

1. **Verify OAuth configuration:**

   ```bash
   # Check if OAuthClient was created
   oc get oauthclient argocd -o yaml
   ```

2. **Recreate Dex pod:**

   ```bash
   oc delete pod -n rhdh -l app.kubernetes.io/name=argocd-dex-server
   ```

3. **Check RBAC configuration:**

   The ArgoCD CR includes RBAC policy. Verify it matches your cluster groups:

   ```bash
   oc get argocd argocd -n rhdh -o jsonpath='{.spec.rbac}'
   ```

---

## Application Sync Issues

### Applications Not Syncing

**Symptoms:**

- Application status stuck in "OutOfSync"
- Manual sync fails

**Diagnosis:**

```bash
# Check application status
oc get application -n rhdh

# Get detailed application info
oc describe application demo-guestbook-app -n rhdh

# Check application controller logs
oc logs -n rhdh deployment/argocd-application-controller
```

**Solutions:**

1. **Check Git repository accessibility:**

   ```bash
   # Try to access the repo from a pod
   oc run test-curl --image=curlimages/curl --rm -it --restart=Never -- \
     curl -I https://github.com/argoproj/argocd-example-apps.git
   ```

2. **Verify sync policy:**

   ```bash
   # Check if auto-sync is enabled
   oc get application demo-guestbook-app -n rhdh -o jsonpath='{.spec.syncPolicy}'
   ```

3. **Manually trigger sync:**

   ```bash
   # Using ArgoCD CLI
   argocd app sync demo-guestbook-app --server $(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')
   
   # Or patch the application
   oc patch application demo-guestbook-app -n rhdh --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
   ```

### Application Health Status Unknown/Degraded

**Symptoms:**

- Application shows "Unknown" health status
- Resources deployed but health check fails

**Diagnosis:**

```bash
# Check application resources
argocd app get demo-guestbook-app --server $(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')

# Check individual resource status
oc get all -n rhdh -l app.kubernetes.io/instance=demo-guestbook-app
```

**Solutions:**

1. **Check resource health:**

   ```bash
   # Check pods
   oc get pods -n rhdh -l app.kubernetes.io/instance=demo-guestbook-app
   
   # Check events
   oc get events -n rhdh | grep guestbook
   ```

2. **Review application manifests:**

   ```bash
   # Check what ArgoCD is trying to deploy
   argocd app manifests demo-guestbook-app
   ```

### Repository Connection Issues

**Symptoms:**

- "Unable to connect to repository" error
- "Repository not found" errors

**Diagnosis:**

```bash
# Check repo server logs
oc logs -n rhdh deployment/argocd-repo-server

# List repositories
argocd repo list --server $(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')
```

**Solutions:**

1. **Verify network connectivity:**

   ```bash
   # Test from repo server pod
   oc exec -n rhdh deployment/argocd-repo-server -- \
     curl -I https://github.com/argoproj/argocd-example-apps.git
   ```

2. **Check for proxy/firewall issues:**

   ```bash
   # Verify no egress restrictions
   oc get networkpolicies -n rhdh
   ```

---

## Plugin Integration Issues

### Plugin Not Showing Applications in RHDH

**Symptoms:**

- ArgoCD tab empty in RHDH component page
- "No applications found" message

**Diagnosis:**

```bash
# 1. Verify applications exist in ArgoCD
argocd app list --server $(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')

# 2. Check RHDH backend logs for ArgoCD errors
oc logs -n rhdh deployment/backstage -c backstage-backend | grep -i argocd

# 3. Verify annotations in catalog entity
oc get configmap argocd-demo-entities-config-map -n rhdh -o yaml
```

**Solutions:**

1. **Verify correct plugin annotations:**

   For Backstage Community plugins:

   ```yaml
   annotations:
     argocd/app-selector: rht-gitops.com/demo-argocd=guestbook-app
   ```

   For RoadieHQ plugins:

   ```yaml
   annotations:
     argocd/app-name: demo-guestbook-app
   ```

2. **Check app-config.yaml configuration:**

   ```bash
   # Verify ArgoCD configuration exists
   oc get configmap app-config-rhdh -n rhdh -o yaml | grep -A10 argocd
   ```

3. **Verify environment variables:**

   ```bash
   # Check secrets are populated
   oc get secret rhdh-secrets -n rhdh -o yaml
   ```

### Wrong Annotation Style

**Symptoms:**

- Using RoadieHQ plugin with Backstage Community annotations (or vice versa)
- Applications not appearing despite correct setup

**Solution:**

Ensure you're using the correct annotation style for your plugin choice:

| Plugin Set          | Annotation                                   |
| ------------------- | -------------------------------------------- |
| Backstage Community | `argocd/app-selector: label.key=label.value` |
| RoadieHQ            | `argocd/app-name: my-app`                    |

Update your catalog entities to match the plugin you're using.

### Multiple Plugin Sets Enabled

**Symptoms:**

- Unexpected behavior
- Duplicate ArgoCD tabs/cards

**Solution:**

Disable one pair of plugins. Edit your `dynamic-plugins-configmap.yaml`:

```yaml
# Option A: Enable Backstage Community, disable RoadieHQ
- package: "@backstage-community/plugin-argocd"
  disabled: false
- package: "@backstage-community/plugin-argocd-backend"
  disabled: false
- package: "@roadiehq/backstage-plugin-argo-cd"
  disabled: true
- package: "@roadiehq/backstage-plugin-argo-cd-backend"
  disabled: true
```

---

## Authentication and Authorization

### Cannot Login to ArgoCD UI

**Symptoms:**

- "Invalid username or password" error
- Admin password not working

**Diagnosis:**

```bash
# Get current admin password
oc get secret argocd-cluster -n rhdh -o jsonpath='{.data.admin\.password}' | base64 -d

# If not found, check initial admin secret
oc get secret argocd-initial-admin-secret -n rhdh -o jsonpath='{.data.password}' | base64 -d
```

**Solutions:**

1. **Reset admin password:**

   ```bash
   # Using ArgoCD CLI
   argocd account update-password --account admin --server $(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')
   ```

2. **Use OpenShift OAuth (if configured):**

   Login via "Log in via OpenShift" button using your OpenShift credentials.

### RHDH Plugin Authentication Failing

**Symptoms:**

- "Unauthorized" errors in RHDH logs
- ArgoCD API calls failing

**Diagnosis:**

```bash
# Check if credentials are set
oc get secret rhdh-secrets -n rhdh -o jsonpath='{.data.ARGOCD_PASSWORD}' | base64 -d

# Test ArgoCD API manually
ARGOCD_URL=$(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')
ARGOCD_PASS=$(oc get secret argocd-cluster -n rhdh -o jsonpath='{.data.admin\.password}' | base64 -d)

curl -k https://${ARGOCD_URL}/api/v1/session \
  -d '{"username":"admin","password":"'$ARGOCD_PASS'"}'
```

**Solutions:**

1. **Regenerate credentials:**

   ```bash
   ./scripts/config-argocd-plugin.sh
   ```

2. **Verify app-config.yaml has correct env var references:**

   ```yaml
   argocd:
     appLocatorMethods:
       - type: "config"
         instances:
           - name: argoInstance
             url: ${ARGOCD_URL}
             password: ${ARGOCD_PASSWORD} # or token: ${ARGOCD_AUTH_TOKEN}
   ```

### RBAC Issues - Users Cannot View Applications

**Symptoms:**

- Users see "permission denied" in ArgoCD UI
- Applications visible in ArgoCD CLI but not in UI

**Diagnosis:**

```bash
# Check RBAC configuration
oc get argocd argocd -n rhdh -o jsonpath='{.spec.rbac}'

# Check user's group memberships
oc get groups
```

**Solutions:**

1. **Update RBAC policy in ArgoCD CR:**

   Edit `resources/argocd/argocd-instance.yaml`:

   ```yaml
   spec:
     rbac:
       policy: |
         g, system:cluster-admins, role:admin
         g, cluster-admins, role:admin
         g, developers, role:readonly
   ```

   Apply changes:

   ```bash
   oc apply -f resources/argocd/argocd-instance.yaml -n rhdh
   ```

---

## Network and Connectivity

### ArgoCD Cannot Reach Git Repositories

**Symptoms:**

- "connection refused" errors
- "no route to host" errors

**Diagnosis:**

```bash
# Test connectivity from ArgoCD pods
oc exec -n rhdh deployment/argocd-repo-server -- \
  curl -v https://github.com

# Check network policies
oc get networkpolicies -n rhdh
```

**Solutions:**

1. **Allow egress traffic:**

   If using network policies, ensure egress is allowed:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-argocd-egress
     namespace: rhdh
   spec:
     podSelector:
       matchLabels:
         app.kubernetes.io/part-of: argocd
     policyTypes:
       - Egress
     egress:
       - {}
   ```

2. **Configure HTTP proxy (if needed):**

   Edit ArgoCD CR to add proxy environment variables.

### Cannot Access ArgoCD Route

**Symptoms:**

- Route returns 503
- "Application is not available" page

**Diagnosis:**

```bash
# Check route
oc get route argocd-server -n rhdh -o yaml

# Check service endpoints
oc get endpoints argocd-server -n rhdh

# Check if server pod is ready
oc get pods -n rhdh -l app.kubernetes.io/name=argocd-server
```

**Solutions:**

1. **Verify service is targeting correct pods:**

   ```bash
   oc get service argocd-server -n rhdh -o yaml
   ```

2. **Check pod readiness:**

   ```bash
   oc describe pod -n rhdh -l app.kubernetes.io/name=argocd-server
   ```

---

## Performance Issues

### Slow Application Sync

**Symptoms:**

- Sync operations take very long
- Timeout errors during sync

**Diagnosis:**

```bash
# Check controller resource usage
oc top pods -n rhdh -l app.kubernetes.io/name=argocd-application-controller

# Check controller logs for slow operations
oc logs -n rhdh deployment/argocd-application-controller --tail=100
```

**Solutions:**

1. **Increase controller resources:**

   Edit `resources/argocd/argocd-instance.yaml`:

   ```yaml
   spec:
     controller:
       resources:
         limits:
           cpu: "4"
           memory: 4Gi
         requests:
           cpu: 500m
           memory: 2Gi
   ```

2. **Reduce parallelism for large repos:**

   ```yaml
   spec:
     controller:
       parallelismLimit: 5 # Default is 10
   ```

### High Memory Usage

**Symptoms:**

- ArgoCD pods being OOMKilled
- Slow UI performance

**Diagnosis:**

```bash
# Check memory usage
oc adm top pods -n rhdh | grep argocd

# Check for OOMKilled events
oc get events -n rhdh | grep OOM
```

**Solutions:**

1. **Increase memory limits** (see Advanced Configuration guide)

2. **Enable resource caching:**

   ```yaml
   spec:
     repo:
       env:
         - name: ARGOCD_EXEC_TIMEOUT
           value: "180s"
   ```

---

## Common Error Messages

### "context deadline exceeded"

**Cause:** Timeout waiting for operation to complete

**Solution:**

```bash
# Increase timeout in ArgoCD CR
oc edit argocd argocd -n rhdh
# Add: spec.controller.appResyncPeriod: "300"
```

### "rpc error: code = Unauthenticated"

**Cause:** Invalid or expired authentication token

**Solution:**

```bash
# Regenerate authentication
./scripts/config-argocd-plugin.sh
```

### "PermissionDenied desc = permission denied"

**Cause:** RBAC restrictions

**Solution:**

Update RBAC policy (see RBAC Issues section above)

### "ImagePullBackOff" on ArgoCD pods

**Cause:** Cannot pull ArgoCD images

**Solution:**

```bash
# Check image pull secrets
oc get pods -n rhdh -l app.kubernetes.io/part-of=argocd -o yaml | grep imagePullSecrets

# If using private registry, add pull secret
oc create secret docker-registry my-registry-secret \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypass \
  -n rhdh
```

---

## Getting Help

If you're still experiencing issues:

1. **Collect diagnostics:**

   ```bash
   # Save all ArgoCD resources
   oc get all -n rhdh -l app.kubernetes.io/part-of=argocd -o yaml > argocd-diagnostics.yaml
   
   # Save logs
   oc logs -n rhdh deployment/argocd-server > argocd-server.log
   oc logs -n rhdh deployment/argocd-application-controller > argocd-controller.log
   oc logs -n rhdh deployment/argocd-repo-server > argocd-repo.log
   ```

2. **Check ArgoCD documentation:**
   - [ArgoCD Troubleshooting](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/)

3. **Open an issue with:**
   - Your cluster version
   - ArgoCD operator version
   - Error messages and logs
   - Steps to reproduce

---

## Related Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Advanced Configuration Guide](./argocd-advanced-config.md)
- [ArgoCD Plugin Documentation](../docs/argocd.md)
