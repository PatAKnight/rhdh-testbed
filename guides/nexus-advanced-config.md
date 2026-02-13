# Nexus Repository Manager - Advanced Configuration

This guide covers production-ready configurations, performance tuning, and advanced features for the
Nexus Repository Manager plugin in RHDH.

---

## Table of Contents

- [Persistent Storage](#persistent-storage)
- [Resource Tuning](#resource-tuning)
- [High Availability](#high-availability)
- [Custom Repositories](#custom-repositories)
- [Security Configuration](#security-configuration)
- [Backup and Restore](#backup-and-restore)
- [Monitoring and Metrics](#monitoring-and-metrics)
- [Custom Plugin Configuration](#custom-plugin-configuration)

---

## Persistent Storage

The default demo configuration uses **ephemeral storage** which is lost when the pod restarts. For
production use, configure persistent storage.

### Enable Persistent Volume Claim

Edit `resources/nexus/nexus-repo.yaml`:

```yaml
apiVersion: sonatype.com/v1alpha1
kind: NexusRepo
metadata:
  name: nexus-repo
spec:
  useRedHatImage: true

  networking:
    expose: true
    exposeAs: Route

  nexus:
    # Enable PVC
    volumeClaimTemplate:
      enabled: true
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 50Gi # Adjust size as needed
        # Optional: specify storage class
        # storageClassName: gp2

    resources:
      requests:
        cpu: 1000m
        memory: 4Gi
      limits:
        cpu: 4000m
        memory: 8Gi
```

### Storage Sizing Guidelines

| Environment | Recommended Size | Notes                               |
| ----------- | ---------------- | ----------------------------------- |
| Demo/Test   | 10-20Gi          | Ephemeral OK                        |
| Development | 50-100Gi         | Persistent recommended              |
| Staging     | 100-250Gi        | Persistent required                 |
| Production  | 250Gi-1Ti+       | Persistent required, monitor growth |

### Storage Class Selection

**For AWS:**

```yaml
storageClassName: gp3 # Recommended: AWS EBS gp3
```

**For Azure:**

```yaml
storageClassName: managed-premium # Azure Premium SSD
```

**For GCP:**

```yaml
storageClassName: standard-rwo # GCP Persistent Disk
```

**For OpenShift Container Storage:**

```yaml
storageClassName: ocs-storagecluster-ceph-rbd
```

### Migrate from Ephemeral to Persistent

If you already have a running Nexus instance with data you want to preserve:

1. **Export current data:**

   ```bash
   # Create backup of Nexus data
   NEXUS_POD=$(oc get pods -n rhdh -l app=nexus-repo -o jsonpath='{.items[0].metadata.name}')
   oc exec ${NEXUS_POD} -n rhdh -- tar czf /tmp/nexus-backup.tar.gz /nexus-data
   oc cp rhdh/${NEXUS_POD}:/tmp/nexus-backup.tar.gz ./nexus-backup.tar.gz
   ```

2. **Update nexus-repo.yaml** with PVC configuration

3. **Delete and recreate:**

   ```bash
   oc delete nexusrepo nexus-repo -n rhdh
   oc apply -f resources/nexus/nexus-repo.yaml -n rhdh
   ```

4. **Restore data:**
   ```bash
   # Wait for new pod to be ready
   NEXUS_POD=$(oc get pods -n rhdh -l app=nexus-repo -o jsonpath='{.items[0].metadata.name}')
   oc cp ./nexus-backup.tar.gz rhdh/${NEXUS_POD}:/tmp/
   oc exec ${NEXUS_POD} -n rhdh -- tar xzf /tmp/nexus-backup.tar.gz -C /
   oc delete pod ${NEXUS_POD} -n rhdh # Restart to apply
   ```

---

## Resource Tuning

### Memory Configuration

Nexus is a Java application and benefits from proper JVM tuning.

**Minimum Requirements:**

- Development: 2Gi RAM
- Production: 4Gi RAM (8Gi+ recommended)

**Optimal Configuration:**

```yaml
resources:
  requests:
    memory: 4Gi
    cpu: 1000m
  limits:
    memory: 8Gi
    cpu: 4000m
```

### JVM Tuning

For advanced JVM configuration, create a ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nexus-jvm-config
  namespace: rhdh
data:
  jvm.properties: |
    -Xms4g
    -Xmx4g
    -XX:MaxDirectMemorySize=2g
    -XX:+UseG1GC
    -XX:MaxGCPauseMillis=200
    -Djava.util.prefs.userRoot=/nexus-data/javaprefs
```

Then reference in NexusRepo:

```yaml
spec:
  nexus:
    env:
      - name: INSTALL4J_ADD_VM_PARAMS
        valueFrom:
          configMapKeyRef:
            name: nexus-jvm-config
            key: jvm.properties
```

### CPU Considerations

**Recommendations:**

- **Minimum**: 500m (0.5 cores)
- **Recommended**: 1000m-2000m (1-2 cores)
- **High load**: 4000m+ (4+ cores)

### Vertical Pod Autoscaling

Enable VPA for automatic resource adjustment:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: nexus-vpa
  namespace: rhdh
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: StatefulSet
    name: nexus-repo
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
      - containerName: nexus
        minAllowed:
          memory: 2Gi
          cpu: 500m
        maxAllowed:
          memory: 16Gi
          cpu: 8000m
```

---

## High Availability

**Note:** The Nexus Operator currently deploys single-instance Nexus. For HA, you need Nexus
Repository Pro (commercial license).

### HA Options

1. **PostgreSQL Backend** (Pro feature)
2. **Clustered Deployment** (Pro feature)
3. **Active-Passive Failover** (OSS - manual setup)

### Active-Passive Failover (OSS)

For improved availability without Pro license:

1. **Use ReadWriteMany PVC** (if your storage supports it):

   ```yaml
   volumeClaimTemplate:
     enabled: true
     spec:
       accessModes:
         - ReadWriteMany # Requires NFS or similar
   ```

2. **Set up regular backups** (see Backup section)

3. **Use PodDisruptionBudget**:
   ```yaml
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: nexus-pdb
     namespace: rhdh
   spec:
     maxUnavailable: 0
     selector:
       matchLabels:
         app: nexus-repo
   ```

---

## Custom Repositories

### Create Additional Repositories via API

After Nexus is running, you can create custom repositories:

```bash
NEXUS_URL=$(oc get route nexus-repo -n rhdh -o jsonpath='{.spec.host}')
NEXUS_PASS=$(oc get secret nexus-admin-credentials -n rhdh -o jsonpath='{.data.password}' | base64 -d)

# Create a hosted Maven repository
curl -u admin:${NEXUS_PASS} -X POST "https://${NEXUS_URL}/service/rest/v1/repositories/maven/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-maven-repo",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "ALLOW"
    },
    "maven": {
      "versionPolicy": "RELEASE",
      "layoutPolicy": "STRICT"
    }
  }'

# Create a hosted npm repository
curl -u admin:${NEXUS_PASS} -X POST "https://${NEXUS_URL}/service/rest/v1/repositories/npm/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-npm-repo",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "ALLOW_ONCE"
    }
  }'
```

### Create Repository Groups

Group repositories for unified access:

```bash
curl -u admin:${NEXUS_PASS} -X POST "https://${NEXUS_URL}/service/rest/v1/repositories/maven/group" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "maven-all",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "group": {
      "memberNames": [
        "maven-releases",
        "maven-snapshots",
        "maven-central"
      ]
    },
    "maven": {
      "versionPolicy": "MIXED"
    }
  }'
```

### Automate Repository Creation

Create a Job to initialize custom repositories:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: nexus-setup-repositories
  namespace: rhdh
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: setup
          image: curlimages/curl:latest
          command:
            - /bin/sh
            - -c
            - |
              # Wait for Nexus
              until curl -sf http://nexus-repo-service:8081/service/rest/v1/status; do
                sleep 5
              done

              # Create repositories
              curl -u admin:${NEXUS_PASS} -X POST \
                "http://nexus-repo-service:8081/service/rest/v1/repositories/maven/hosted" \
                -H "Content-Type: application/json" \
                -d '{"name":"custom-releases",...}'
          env:
            - name: NEXUS_PASS
              valueFrom:
                secretKeyRef:
                  name: nexus-admin-credentials
                  key: password
```

---

## Security Configuration

### Change Default Admin Password

**Important:** Change the default admin password immediately in production.

```bash
NEXUS_URL=$(oc get route nexus-repo -n rhdh -o jsonpath='{.spec.host}')
OLD_PASS=$(oc get secret nexus-admin-credentials -n rhdh -o jsonpath='{.data.password}' | base64 -d)
NEW_PASS="<your-new-password>"

# Change password via API
curl -u admin:${OLD_PASS} -X PUT "https://${NEXUS_URL}/service/rest/v1/security/users/admin/change-password" \
  -H "Content-Type: text/plain" \
  -d "${NEW_PASS}"

# Update secret
oc create secret generic nexus-admin-credentials \
  --from-literal=password=${NEW_PASS} \
  --dry-run=client -o yaml | oc apply -n rhdh -f -

# Update RHDH secrets
oc patch secret rhdh-secrets -n rhdh --type merge -p "{\"data\":{\"NEXUS_PASSWORD\":\"$(echo -n ${NEW_PASS} | base64 -w 0)\"}}"
```

### Enable LDAP Authentication

Integrate with external LDAP/Active Directory:

```bash
curl -u admin:${NEXUS_PASS} -X POST "https://${NEXUS_URL}/service/rest/v1/security/ldap" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "corporate-ldap",
    "protocol": "ldaps",
    "host": "ldap.example.com",
    "port": 636,
    "searchBase": "dc=example,dc=com",
    "authScheme": "simple",
    "authUsername": "cn=nexus,ou=service-accounts,dc=example,dc=com",
    "authPassword": "<service-account-password>",
    "userBaseDn": "ou=users",
    "userSubtree": true,
    "userObjectClass": "inetOrgPerson",
    "userIdAttribute": "uid",
    "userRealNameAttribute": "cn",
    "userEmailAddressAttribute": "mail"
  }'
```

### Configure Role-Based Access Control (RBAC)

Create custom roles:

```bash
# Create developer role with read-only access
curl -u admin:${NEXUS_PASS} -X POST "https://${NEXUS_URL}/service/rest/v1/security/roles" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "developer",
    "name": "Developer",
    "description": "Read-only access to artifacts",
    "privileges": [
      "nx-repository-view-*-*-read",
      "nx-repository-view-*-*-browse"
    ]
  }'
```

### Enable SSL/TLS

The operator creates a route with OpenShift's default TLS. For custom certificates:

```bash
# Create TLS secret
oc create secret tls nexus-tls \
  --cert=nexus.crt \
  --key=nexus.key \
  -n rhdh

# Patch route to use custom cert
oc patch route nexus-repo -n rhdh -p '{
  "spec": {
    "tls": {
      "certificate": "<BASE64_CERT>",
      "key": "<BASE64_KEY>"
    }
  }
}'
```

---

## Backup and Restore

### Backup Strategy

**Recommended approach:**

1. **Backup blob stores** (contains actual artifacts)
2. **Backup database** (metadata and configuration)
3. **Backup configuration** (admin password, repositories)

### Manual Backup

```bash
NEXUS_POD=$(oc get pods -n rhdh -l app=nexus-repo -o jsonpath='{.items[0].metadata.name}')

# Full backup
oc exec ${NEXUS_POD} -n rhdh -- tar czf /tmp/nexus-full-backup.tar.gz /nexus-data

# Download backup
oc cp rhdh/${NEXUS_POD}:/tmp/nexus-full-backup.tar.gz ./nexus-backup-$(date +%Y%m%d).tar.gz
```

### Automated Backups with CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nexus-backup
  namespace: rhdh
spec:
  schedule: "0 2 * * *" # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: registry.access.redhat.com/ubi9/ubi:latest
              command:
                - /bin/bash
                - -c
                - |
                  # Install dependencies
                  dnf install -y tar gzip aws-cli

                  # Create backup
                  tar czf /tmp/nexus-backup-$(date +%Y%m%d).tar.gz /nexus-data

                  # Upload to S3 (or your backup storage)
                  aws s3 cp /tmp/nexus-backup-*.tar.gz s3://my-backups/nexus/
              volumeMounts:
                - name: nexus-data
                  mountPath: /nexus-data
                  readOnly: true
              env:
                - name: AWS_ACCESS_KEY_ID
                  valueFrom:
                    secretKeyRef:
                      name: aws-credentials
                      key: access-key-id
                - name: AWS_SECRET_ACCESS_KEY
                  valueFrom:
                    secretKeyRef:
                      name: aws-credentials
                      key: secret-access-key
          volumes:
            - name: nexus-data
              persistentVolumeClaim:
                claimName: nexus-pvc
          restartPolicy: OnFailure
```

### Restore from Backup

```bash
# Stop Nexus
oc scale statefulset nexus-repo --replicas=0 -n rhdh

# Upload and extract backup
oc cp nexus-backup-20241201.tar.gz rhdh/ < pod-name > :/tmp/
oc exec rhdh -- tar xzf /tmp/nexus-backup-20241201.tar.gz -C / < pod-name > -n

# Restart Nexus
oc scale statefulset nexus-repo --replicas=1 -n rhdh
```

---

## Monitoring and Metrics

### Enable Prometheus Metrics

Nexus exposes metrics for Prometheus:

```yaml
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nexus-metrics
  namespace: rhdh
  labels:
    app: nexus-repo
spec:
  selector:
    matchLabels:
      app: nexus-repo
  endpoints:
    - port: http
      path: /service/metrics/prometheus
      interval: 30s
```

### Key Metrics to Monitor

| Metric                                   | Description           | Alert Threshold |
| ---------------------------------------- | --------------------- | --------------- |
| `nexus_blobstore_total_size_bytes`       | Total blob store size | > 80% capacity  |
| `nexus_jvm_memory_used_bytes`            | JVM memory usage      | > 90% limit     |
| `nexus_repository_component_total_count` | Number of components  | Growth rate     |
| `nexus_http_requests_total`              | HTTP request rate     | Sudden drops    |

### Grafana Dashboard

Import the Nexus dashboard:

```bash
# Dashboard ID: 13463 (from grafana.com)
# Or create custom dashboard with above metrics
```

### Health Checks

Configure liveness and readiness probes:

```yaml
spec:
  nexus:
    livenessProbe:
      httpGet:
        path: /service/rest/v1/status
        port: 8081
      initialDelaySeconds: 180
      periodSeconds: 30
      timeoutSeconds: 10
      failureThreshold: 6

    readinessProbe:
      httpGet:
        path: /service/rest/v1/status
        port: 8081
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
```

---

## Custom Plugin Configuration

### Required Proxy Configuration

The Nexus Repository Manager plugin is a **frontend plugin** that requires proxy configuration in
the dynamic plugins configmap. This is different from backend plugins that use app-config.yaml.

**Complete plugin configuration:**

```yaml
- package: "@janus-idp/backstage-plugin-nexus-repository-manager"
  disabled: false
  pluginConfig:
    dynamicPlugins:
      frontend:
        janus-idp.backstage-plugin-nexus-repository-manager:
          mountPoints:
            - mountPoint: entity.page.image-registry/cards
              importName: NexusRepositoryManagerPage
              config:
                layout:
                  gridColumn: 1 / -1
                if:
                  anyOf:
                    - isNexusRepositoryManagerAvailable
    proxy:
      endpoints:
        "/nexus-repository-manager":
          target: "${NEXUS_URL}"
          headers:
            X-Requested-With: "XMLHttpRequest"
            Authorization: "Basic ${NEXUS_AUTH_HEADER}"
          changeOrigin: true
          secure: true
```

**Environment Variables Required:**

- `NEXUS_URL` - Full Nexus URL (e.g., `https://nexus.example.com`)
- `NEXUS_AUTH_HEADER` - Base64-encoded `username:password` for HTTP Basic auth

### Generating Auth Header

The setup script automatically generates this, but for manual configuration:

```bash
# Generate auth header
USERNAME="admin"
PASSWORD="<your-password>"
AUTH_HEADER=$(echo -n "${USERNAME}:${PASSWORD}" | base64 -w 0)

# Add to secrets
oc patch secret rhdh-secrets -n rhdh --type merge -p "{\"data\":{\"NEXUS_AUTH_HEADER\":\"$(echo -n ${AUTH_HEADER} | base64 -w 0)\"}}"
```

### Why Proxy Configuration?

Frontend plugins make API calls from the user's browser. The proxy:

1. **Avoids CORS** - Browsers block cross-origin requests
2. **Handles Authentication** - Keeps credentials server-side
3. **Simplifies SSL** - Handles certificate validation centrally
4. **Provides Caching** - Can cache responses for performance

### Advanced Annotation Usage

Use multiple annotations for richer queries:

```yaml
metadata:
  annotations:
    # Query by multiple criteria
    nexus-repository-manager/repository: maven-releases
    nexus-repository-manager/maven.group-id: com.example
    nexus-repository-manager/maven.artifact-id: myapp
    nexus-repository-manager/maven.base-version: 1.0.0

    # Add custom title
    nexus-repository-manager/config.title: "Production Artifacts"
```

### Configure Plugin Polling Interval

In RHDH app-config:

```yaml
nexusRepositoryManager:
  baseUrl: ${NEXUS_URL}
  username: ${NEXUS_USERNAME}
  password: ${NEXUS_PASSWORD}
  cache:
    ttl: 300000 # 5 minutes in milliseconds
```

### Custom Component Card Layout

```yaml
- package: "@janus-idp/backstage-plugin-nexus-repository-manager"
  disabled: false
  pluginConfig:
    dynamicPlugins:
      frontend:
        janus-idp.backstage-plugin-nexus-repository-manager:
          mountPoints:
            - mountPoint: entity.page.overview/cards
              importName: EntityNexusRepositoryManagerCard
              config:
                layout:
                  gridColumn: 1 / -1 # Full width
                  gridRow: auto
                if:
                  allOf:
                    - isNexusAvailable # Only show if annotations present
```

---

## Performance Optimization

### Connection Pooling

Configure connection pools for high-traffic scenarios:

```yaml
env:
  - name: NEXUS_DATASTORE_NEXUS_JDBC_URL
    value: "jdbc:h2:file:/nexus-data/db/nexus"
  - name: NEXUS_DATASTORE_NEXUS_POOL_MAXPOOLSIZE
    value: "50"
  - name: NEXUS_DATASTORE_NEXUS_POOL_MINPOOLSIZE
    value: "10"
```

### Cleanup Policies

Automate cleanup of old artifacts:

```bash
curl -u admin:${NEXUS_PASS} -X POST "https://${NEXUS_URL}/service/rest/v1/cleanup-policies" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "cleanup-old-snapshots",
    "format": "maven2",
    "notes": "Remove snapshots older than 30 days",
    "criteriaLastBlobUpdated": 30,
    "criteriaReleaseType": "SNAPSHOTS"
  }'
```

### Enable Request Caching

Add a caching proxy (Varnish, nginx) in front of Nexus for static assets.

---

## Production Checklist

Before going to production:

- [ ] Enable persistent storage with adequate sizing
- [ ] Configure resource limits based on expected load
- [ ] Change default admin password
- [ ] Set up LDAP/SSO authentication
- [ ] Configure RBAC for different user roles
- [ ] Enable SSL/TLS with valid certificates
- [ ] Set up automated backups
- [ ] Configure monitoring and alerting
- [ ] Test disaster recovery procedures
- [ ] Document repository structure and policies
- [ ] Configure cleanup policies for old artifacts
- [ ] Review and adjust JVM settings
- [ ] Set up log aggregation
- [ ] Configure network policies
- [ ] Test failover procedures

---

## Additional Resources

- [Nexus Repository Manager Documentation](https://help.sonatype.com/repomanager3)
- [Nexus Operator GitHub](https://github.com/sonatype/operator-nxrm3)
- [Nexus REST API Reference](https://help.sonatype.com/repomanager3/rest-and-integration-api)
- [Performance and Scaling Guide](https://help.sonatype.com/repomanager3/planning-your-implementation/performance-and-scaling)
