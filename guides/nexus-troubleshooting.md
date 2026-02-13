# Nexus Repository Manager - Troubleshooting Guide

This guide helps you diagnose and fix common issues with the Nexus Repository Manager plugin for
RHDH.

---

## Table of Contents

- [Operator Issues](#operator-issues)
- [Nexus Instance Issues](#nexus-instance-issues)
- [Demo Data Issues](#demo-data-issues)
- [Plugin Integration Issues](#plugin-integration-issues)
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
oc get subscription nexus-operator-subscription -n rhdh -o yaml

# Check install plan
oc get installplan -n rhdh

# Check for operator pod issues
oc get pods -n openshift-marketplace | grep certified-operators
```

**Solutions:**

1. **Verify operator catalog is healthy:**

   ```bash
   oc get catalogsource -n openshift-marketplace
   oc get pods -n openshift-marketplace
   ```

2. **Check for approval requirements:**

   ```bash
   # If manual approval is needed
   INSTALL_PLAN=$(oc get installplan -n rhdh -o jsonpath='{.items[0].metadata.name}')
   oc patch installplan ${INSTALL_PLAN} -n rhdh --type merge -p '{"spec":{"approved":true}}'
   ```

3. **Restart marketplace operators:**

   ```bash
   oc delete pod -n openshift-marketplace -l marketplace.redhat.com/name=certified-operators
   ```

4. **Check for resource conflicts:**

   ```bash
   # Look for existing Nexus CRDs
   oc get crd | grep nexus
   
   # If old CRDs exist, they may conflict
   # Only delete if you're sure they're not in use
   ```

### Operator CSV Fails

**Symptoms:**

- CSV shows "Failed" status
- Operator pod is CrashLooping

**Diagnosis:**

```bash
# Check CSV status
oc get csv -n rhdh | grep nxrm-operator

# Check operator pod logs
OPERATOR_POD=$(oc get pods -n rhdh -l app=nxrm-operator -o name)
oc logs ${OPERATOR_POD} -n rhdh
```

**Solutions:**

1. **Check RBAC permissions:**

   ```bash
   # Operator needs proper ClusterRole permissions
   oc get clusterrole | grep nxrm
   oc describe clusterrole nxrm-operator
   ```

2. **Reinstall operator:**

   ```bash
   # Delete CSV (subscription will recreate it)
   CSV_NAME=$(oc get csv -n rhdh | grep nxrm-operator | awk '{print $1}')
   oc delete csv ${CSV_NAME} -n rhdh
   
   # Wait for automatic recreation
   oc get csv -n rhdh -w
   ```

---

## Nexus Instance Issues

### Nexus Instance Won't Start

**Symptoms:**

- NexusRepo CR exists but no pods are created
- Pods are created but crash immediately

**Diagnosis:**

```bash
# Check NexusRepo resource status
oc get nexusrepo nexus-repo -n rhdh -o yaml

# Check for pods
oc get pods -n rhdh | grep nexus

# If pods exist, check logs
oc logs -n rhdh -l app=nexus-repo --tail=100
```

**Solutions:**

1. **Check resource limits:**

   ```bash
   # Nexus needs at least 2Gi memory
   oc describe nexusrepo nexus-repo -n rhdh | grep -A 10 resources
   ```

   If insufficient, update `resources/nexus/nexus-repo.yaml`:

   ```yaml
   resources:
     requests:
       memory: 2Gi
       cpu: 500m
     limits:
       memory: 4Gi
       cpu: 2000m
   ```

2. **Check namespace quotas:**

   ```bash
   oc get resourcequota -n rhdh
   oc describe resourcequota -n rhdh
   ```

3. **Check storage:**

   ```bash
   # If using PVC (not ephemeral)
   oc get pvc -n rhdh
   oc describe pvc nexus-pvc -n rhdh
   ```

4. **Check operator logs:**
   ```bash
   oc logs -n rhdh -l app=nxrm-operator --tail=200
   ```

### Nexus Pod is CrashLooping

**Symptoms:**

- Pod restarts repeatedly
- Status shows `CrashLoopBackOff`

**Diagnosis:**

```bash
# Get pod name
NEXUS_POD=$(oc get pods -n rhdh -l app=nexus-repo -o name)

# Check recent logs
oc logs ${NEXUS_POD} -n rhdh --tail=100

# Check previous container logs
oc logs ${NEXUS_POD} -n rhdh --previous --tail=100

# Check events
oc get events -n rhdh --sort-by='.lastTimestamp' | grep nexus
```

**Common Causes & Solutions:**

1. **Out of Memory:**

   ```
   Error: java.lang.OutOfMemoryError: Java heap space
   ```

   **Solution:** Increase memory in nexus-repo.yaml

2. **Permissions Issue:**

   ```
   Error: Permission denied
   ```

   **Solution:** Check securityContext settings

   ```yaml
   securityContext:
     fsGroup: 200
     runAsUser: 200
   ```

3. **Port Conflict:**
   ```
   Error: Address already in use
   ```
   **Solution:** Check for service conflicts
   ```bash
   oc get svc -n rhdh | grep 8081
   ```

### Nexus is Slow to Start

**Symptoms:**

- Pod is running but Nexus UI not accessible
- Takes > 5 minutes to become ready

**This is Normal:**

- Nexus typically takes 2-3 minutes for initial startup
- First-time initialization can take up to 5 minutes

**Check Progress:**

```bash
# Watch pod logs for startup messages
oc logs -n rhdh -l app=nexus-repo -f | grep "Started Sonatype Nexus"

# Check readiness probes
oc describe pod -n rhdh -l app=nexus-repo | grep -A 5 Readiness
```

**If Taking > 10 Minutes:**

```bash
# Check for Java errors
oc logs -n rhdh -l app=nexus-repo | grep -i error

# Check resource constraints
oc top pod -n rhdh -l app=nexus-repo
```

---

## Demo Data Issues

### Demo Data Job Fails

**Symptoms:**

- Job shows "Error" or "Failed" status
- Job never completes

**Diagnosis:**

```bash
# Check job status
oc get job nexus-populate-demo-data -n rhdh

# Check pod status
oc get pods -n rhdh | grep nexus-populate-demo-data

# View logs
oc logs -n rhdh job/nexus-populate-demo-data --tail=200
```

**Common Issues:**

1. **Nexus Not Ready:**

   ```
   Error: Connection refused
   ```

   **Solution:** Job runs too early. Wait for Nexus to be fully ready:

   ```bash
   oc delete job nexus-populate-demo-data -n rhdh
   # Wait 2-3 minutes after Nexus pod is running
   oc apply -f resources/nexus/populate-demo-data-job.yaml -n rhdh
   ```

2. **Authentication Failed:**

   ```
   Error: 401 Unauthorized
   ```

   **Solution:** Check admin credentials:

   ```bash
   oc get secret nexus-admin-credentials -n rhdh
   ```

3. **Repository Doesn't Exist:**

   ```
   Error: 404 Not Found
   ```

   **Solution:** Repositories not initialized. Wait longer or check Nexus UI.

4. **Network Policy Blocking:**
   ```
   Error: timeout
   ```
   **Solution:** Check network policies:
   ```bash
   oc get networkpolicy -n rhdh
   ```

### Re-running Demo Data Job

If job fails and you want to retry:

```bash
# Delete failed job
oc delete job nexus-populate-demo-data -n rhdh

# Ensure Nexus is ready
oc get nexusrepo nexus-repo -n rhdh
# Should show status: Running or Ready

# Re-apply job
oc apply -f resources/nexus/populate-demo-data-job.yaml -n rhdh

# Watch progress
oc logs -n rhdh job/nexus-populate-demo-data -f
```

### Artifacts Not Showing in Nexus UI

**Check if artifacts were uploaded:**

```bash
NEXUS_URL=$(oc get route nexus-repo -n rhdh -o jsonpath='{.spec.host}')
NEXUS_PASS=$(oc get secret nexus-admin-credentials -n rhdh -o jsonpath='{.data.password}' | base64 -d)

# Check Maven artifacts
curl -u admin:${NEXUS_PASS} "https://${NEXUS_URL}/service/rest/v1/components?repository=maven-releases" | jq

# Check npm artifacts
curl -u admin:${NEXUS_PASS} "https://${NEXUS_URL}/service/rest/v1/components?repository=npm-internal" | jq
```

---

## Plugin Integration Issues

### Plugin Not Showing in RHDH

**Diagnosis:**

```bash
# Check if plugin is enabled
oc get configmap dynamic-plugins-configmap -n rhdh -o yaml | grep nexus-repository-manager

# Check RHDH logs
RHDH_POD=$(oc get pods -n rhdh -l app=backstage -o name)
oc logs ${RHDH_POD} -n rhdh | grep -i nexus
```

**Solutions:**

1. **Plugin not enabled:** Edit dynamic-plugins-configmap.yaml:

   ```yaml
   - package: "@janus-idp/backstage-plugin-nexus-repository-manager"
     disabled: false # Make sure this is false
   ```

2. **Restart RHDH:**
   ```bash
   oc rollout restart deployment/backstage -n rhdh
   oc rollout status deployment/backstage -n rhdh
   ```

### Catalog Entities Not Appearing

**Diagnosis:**

```bash
# Check if ConfigMap exists
oc get configmap nexus-demo-entities-config-map -n rhdh

# Check if it has the correct label
oc get configmap nexus-demo-entities-config-map -n rhdh -o yaml | grep backstage.io/kubernetes-id

# Check RHDH catalog processing
RHDH_POD=$(oc get pods -n rhdh -l app=backstage -o name)
oc logs ${RHDH_POD} -n rhdh | grep -i "catalog.*entity"
```

**Solutions:**

1. **Missing or incorrect label:**

   ```bash
   oc label configmap nexus-demo-entities-config-map \
     backstage.io/kubernetes-id=developer-hub \
     --overwrite -n rhdh
   ```

2. **Refresh catalog:**
   - In RHDH UI: Settings → Catalog → Refresh

3. **Check entity processing errors:**
   - Navigate to RHDH UI → Settings → Catalog → Unprocessed Entities

### Plugin Shows "No Data" or "Connection Error"

**Check Nexus connection from RHDH:**

1. **Verify secrets are configured:**

   ```bash
   oc get secret rhdh-secrets -n rhdh -o yaml | grep NEXUS
   ```

2. **Check app-config:**

   ```bash
   oc get configmap app-config-rhdh -n rhdh -o yaml | grep -A 5 nexusRepositoryManager
   ```

3. **Test connectivity from RHDH pod:**
   ```bash
   RHDH_POD=$(oc get pods -n rhdh -l app=backstage -o jsonpath='{.items[0].metadata.name}')
   oc exec ${RHDH_POD} -n rhdh -- curl -v http://nexus-repo-service:8081/service/rest/v1/status
   ```

### Annotations Not Working

**Verify annotation format:**

Correct format:

```yaml
annotations:
  nexus-repository-manager/repository: maven-releases
  nexus-repository-manager/maven.group-id: com.example.demo
  nexus-repository-manager/maven.artifact-id: hello-world-lib
  nexus-repository-manager/maven.base-version: 1.0.0
```

See
[official annotations documentation](https://github.com/backstage/community-plugins/blob/main/workspaces/nexus-repository-manager/plugins/nexus-repository-manager/ANNOTATIONS.md).

---

## Network and Connectivity

### Cannot Access Nexus UI

**Diagnosis:**

```bash
# Check route exists
oc get route nexus-repo -n rhdh

# Check route status
oc describe route nexus-repo -n rhdh

# Test from outside cluster
NEXUS_URL=$(oc get route nexus-repo -n rhdh -o jsonpath='{.spec.host}')
curl -v https://${NEXUS_URL}
```

**Solutions:**

1. **Route not created:** Check nexus-repo.yaml has:

   ```yaml
   networking:
     expose: true
     exposeAs: Route
   ```

2. **TLS certificate issues:**

   ```bash
   # Check certificate
   echo | openssl s_client -servername ${NEXUS_URL} -connect ${NEXUS_URL}:443 2> /dev/null | openssl x509 -noout -dates
   ```

3. **Firewall/Network policy:**
   ```bash
   oc get networkpolicy -n rhdh
   ```

### Service-to-Service Communication Fails

**Test internal connectivity:**

```bash
# From demo data job perspective
oc run test-curl --image=curlimages/curl -n rhdh --rm -it -- curl -v http://nexus-repo-service:8081/service/rest/v1/status
```

**Check service:**

```bash
oc get svc nexus-repo-service -n rhdh
oc describe svc nexus-repo-service -n rhdh
```

---

## Performance Issues

### Nexus is Slow

**Check resource usage:**

```bash
# Check current usage
oc top pod -n rhdh -l app=nexus-repo

# Check limits
oc get nexusrepo nexus-repo -n rhdh -o yaml | grep -A 10 resources
```

**Increase resources:** Edit nexus-repo.yaml:

```yaml
resources:
  requests:
    cpu: 1000m
    memory: 4Gi
  limits:
    cpu: 4000m
    memory: 8Gi
```

Apply changes:

```bash
oc apply -f resources/nexus/nexus-repo.yaml -n rhdh
# Pod will be recreated with new limits
```

### Storage Running Out

**Check storage usage:**

```bash
# If using PVC
oc get pvc -n rhdh
oc exec -n rhdh -l app=nexus-repo -- df -h /nexus-data

# Check for ephemeral storage warnings
oc describe pod -n rhdh -l app=nexus-repo | grep -i ephemeral
```

**Switch to persistent storage:** See
[Nexus Advanced Configuration](nexus-advanced-config.md#persistent-storage).

---

## Common Error Messages

### "Failed to pull image"

**Full Error:**

```
Failed to pull image "registry.connect.redhat.com/sonatype/nexus-repository-manager:..."
```

**Solution:** Ensure proper image pull secrets or use useRedHatImage:

```yaml
spec:
  useRedHatImage: true
```

### "NexusRepo CRD not found"

**Error:**

```
no matches for kind "NexusRepo" in version "sonatype.com/v1alpha1"
```

**Solution:** Operator not installed or CRD not registered:

```bash
# Check CRD
oc get crd nexusrepos.sonatype.com

# If missing, reinstall operator
oc delete subscription nexus-operator-subscription -n rhdh
oc apply -f resources/operators/nexus-subscription.yaml -n rhdh
```

### "Address already in use"

**Error:**

```
java.net.BindException: Address already in use
```

**Solution:** Port 8081 is occupied. Check for conflicts:

```bash
oc get svc -n rhdh
oc get pods -n rhdh -o wide
```

### "Insufficient CPU/Memory"

**Error:**

```
Insufficient cpu/memory
```

**Solution:** Namespace has resource quotas. Check and adjust:

```bash
oc get resourcequota -n rhdh -o yaml
# Contact cluster admin to increase quota if needed
```

---

## Getting Help

If issues persist:

1. **Collect diagnostic information:**

   ```bash
   # Save all relevant resources
   oc get all,configmap,secret,nexusrepo -n rhdh -o yaml > nexus-diagnostics.yaml
   
   # Get operator logs
   oc logs -n rhdh -l app=nxrm-operator --tail=500 > operator-logs.txt
   
   # Get Nexus logs
   oc logs -n rhdh -l app=nexus-repo --tail=500 > nexus-logs.txt
   
   # Get demo job logs
   oc logs -n rhdh job/nexus-populate-demo-data > demo-job-logs.txt
   ```

2. **Check official documentation:**
   - [Nexus Operator Docs](https://github.com/sonatype/operator-nxrm3)
   - [Backstage Plugin Docs](https://github.com/backstage/community-plugins/tree/main/workspaces/nexus-repository-manager)

3. **Search for similar issues:**
   - [Nexus Operator Issues](https://github.com/sonatype/operator-nxrm3/issues)
   - [Plugin Issues](https://github.com/backstage/community-plugins/issues)
