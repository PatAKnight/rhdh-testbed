# ArgoCD - Advanced Configuration

This guide covers production-ready configurations, performance tuning, and advanced features for the
ArgoCD plugins in RHDH.

---

## Table of Contents

- [High Availability](#high-availability)
- [Resource Tuning](#resource-tuning)
- [Multiple ArgoCD Instances](#multiple-argocd-instances)
- [Security Configuration](#security-configuration)
- [Git Repository Configuration](#git-repository-configuration)
- [Application Sets](#application-sets)
- [Custom Health Checks](#custom-health-checks)
- [Notifications and Webhooks](#notifications-and-webhooks)
- [Backup and Restore](#backup-and-restore)
- [Monitoring and Metrics](#monitoring-and-metrics)

---

## High Availability

The default demo configuration runs a single instance of each ArgoCD component. For production,
enable High Availability mode.

### Enable HA Mode

Edit `resources/argocd/argocd-instance.yaml`:

```yaml
apiVersion: argoproj.io/v1beta1
kind: ArgoCD
metadata:
  name: argocd
  namespace: rhdh
spec:
  ha:
    enabled: true
    # Redis HA configuration
    redisProxyImage: haproxy
    redisProxyVersion: "2.0.4"

  # Scale server replicas
  server:
    replicas: 3
    autoscale:
      enabled: true
      hpa:
        minReplicas: 3
        maxReplicas: 5
        targetCPUUtilizationPercentage: 50

  # Scale repo server
  repo:
    replicas: 3
    autoscale:
      enabled: true
      hpa:
        minReplicas: 3
        maxReplicas: 5
        targetCPUUtilizationPercentage: 50

  # Application controller (runs as single instance with leader election)
  controller:
    sharding:
      enabled: true
      replicas: 3
```

Apply the configuration:

```bash
oc apply -f resources/argocd/argocd-instance.yaml -n rhdh
```

### Redis HA

For production workloads, configure Redis in HA mode:

```yaml
spec:
  redis:
    resources:
      limits:
        cpu: "1"
        memory: 512Mi
      requests:
        cpu: 250m
        memory: 256Mi

  ha:
    enabled: true
    # Use Redis Sentinel for automatic failover
    redisProxyImage: haproxy
    redisProxyVersion: "2.0.4"
```

---

## Resource Tuning

Optimize resource allocation based on your workload.

### Recommended Production Resources

```yaml
apiVersion: argoproj.io/v1beta1
kind: ArgoCD
metadata:
  name: argocd
  namespace: rhdh
spec:
  # Application Controller - handles sync operations
  controller:
    resources:
      limits:
        cpu: "4"
        memory: 4Gi
      requests:
        cpu: "1"
        memory: 2Gi
    # Adjust based on number of applications
    sharding:
      enabled: true
      replicas: 3
    # Tuning parameters
    env:
      - name: ARGOCD_RECONCILIATION_TIMEOUT
        value: "180s"
      - name: ARGOCD_REPO_SERVER_TIMEOUT_SECONDS
        value: "120"

  # Repo Server - handles Git operations
  repo:
    resources:
      limits:
        cpu: "2"
        memory: 2Gi
      requests:
        cpu: 500m
        memory: 1Gi
    # Cache configuration for better performance
    env:
      - name: ARGOCD_GIT_MODULES_ENABLED
        value: "false"
      - name: ARGOCD_EXEC_TIMEOUT
        value: "180s"
    mountsatoken: true
    serviceaccount: argocd-repo-server
    replicas: 3

  # API Server - handles UI and API requests
  server:
    resources:
      limits:
        cpu: "2"
        memory: 1Gi
      requests:
        cpu: 500m
        memory: 512Mi
    replicas: 3
    insecure: false

  # Redis - caching layer
  redis:
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 250m
        memory: 256Mi

  # Dex - SSO/OAuth
  dex:
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 250m
        memory: 128Mi

  # ApplicationSet Controller
  applicationSet:
    resources:
      limits:
        cpu: "2"
        memory: 1Gi
      requests:
        cpu: 250m
        memory: 512Mi
```

### Sizing Guidelines

| Cluster Size    | Applications | Controller CPU | Controller Memory | Repo Server Replicas |
| --------------- | ------------ | -------------- | ----------------- | -------------------- |
| Small (< 50)    | < 50         | 1 core         | 2Gi               | 1-2                  |
| Medium (50-200) | 50-200       | 2 cores        | 4Gi               | 2-3                  |
| Large (200-500) | 200-500      | 4 cores        | 8Gi               | 3-5                  |
| XLarge (> 500)  | > 500        | 8 cores        | 16Gi              | 5-10                 |

---

## Multiple ArgoCD Instances

Support multiple ArgoCD instances (dev, staging, prod) in RHDH.

### Deploy Additional ArgoCD Instance

Create a new ArgoCD instance CR:

```yaml
# resources/argocd/argocd-production.yaml
apiVersion: argoproj.io/v1beta1
kind: ArgoCD
metadata:
  name: argocd-production
  namespace: argocd-prod
spec:
  server:
    route:
      enabled: true
  # ... rest of configuration
```

### Configure Multiple Instances in RHDH

For **Backstage Community plugins**, add to `app-config.yaml`:

```yaml
argocd:
  appLocatorMethods:
    - type: "config"
      instances:
        - name: devInstance
          url: https://argocd-dev.example.com
          token: ${ARGOCD_DEV_TOKEN}
        - name: prodInstance
          url: https://argocd-prod.example.com
          token: ${ARGOCD_PROD_TOKEN}
```

For **RoadieHQ plugins**, add to `app-config.yaml`:

```yaml
argocd:
  appLocatorMethods:
    - type: "config"
      instances:
        - name: devInstance
          url: https://argocd-dev.example.com
          username: ${ARGOCD_DEV_USERNAME}
          password: ${ARGOCD_DEV_PASSWORD}
        - name: prodInstance
          url: https://argocd-prod.example.com
          username: ${ARGOCD_PROD_USERNAME}
          password: ${ARGOCD_PROD_PASSWORD}
```

### Specify Instance in Catalog Entities

For Backstage Community plugins:

```yaml
metadata:
  annotations:
    argocd/app-selector: "app=my-app"
    argocd/instance-name: "prodInstance"
```

For RoadieHQ plugins:

```yaml
metadata:
  annotations:
    argocd/app-name: my-app
    argocd/proxy-url: "/argocd/api-prod" # Point to specific instance
```

---

## Security Configuration

### TLS/SSL Configuration

#### Custom TLS Certificates

```yaml
spec:
  server:
    route:
      enabled: true
      tls:
        termination: reencrypt
        insecureEdgeTerminationPolicy: Redirect
        # Optional: custom certificates
        certificate: |
          # <your-private-key-here>
        key: |
          # <your-private-key-here>
        caCertificate: |
          # <your-private-key-here>
```

#### Insecure Mode (Development Only)

```yaml
spec:
  server:
    insecure: true # Disables TLS
```

### RBAC Configuration

#### Advanced RBAC Policies

```yaml
spec:
  rbac:
    defaultPolicy: "role:readonly"
    policy: |
      # Admin access for cluster admins
      g, system:cluster-admins, role:admin
      g, cluster-admins, role:admin

      # Project-based access
      p, role:project-dev, applications, get, project-dev/*, allow
      p, role:project-dev, applications, sync, project-dev/*, allow
      g, developers, role:project-dev

      # Read-only for viewers
      p, role:viewer, applications, get, */*, allow
      g, viewers, role:viewer

      # Prevent deletion for non-admins
      p, role:project-dev, applications, delete, */*, deny

    scopes: "[groups, email]"
```

#### Anonymous Access

```yaml
spec:
  rbac:
    policy: |
      p, role:anonymous, applications, get, */*, allow
    scopes: "[groups]"

  server:
    # Enable anonymous access
    anonymous:
      enabled: true
```

### SSO Configuration

#### OIDC (Non-OpenShift)

```yaml
spec:
  sso:
    provider: oidc
    oidc:
      name: "My SSO"
      issuer: https://auth.example.com
      clientID: argocd
      clientSecret: ${OIDC_CLIENT_SECRET}
      requestedScopes:
        - openid
        - profile
        - email
        - groups
```

#### SAML

```yaml
spec:
  sso:
    provider: saml
    saml:
      metadataURL: https://auth.example.com/saml/metadata
```

### Repository Credentials

#### SSH Private Key

```bash
# Create secret with SSH key
oc create secret generic git-ssh-credentials \
  --from-file=sshPrivateKey=/path/to/id_rsa \
  -n rhdh

# Reference in ArgoCD
oc label secret git-ssh-credentials argocd.argoproj.io/secret-type=repository -n rhdh
```

#### HTTPS Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-https-credentials
  namespace: rhdh
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/myorg
  username: myuser
  password: mytoken
```

---

## Git Repository Configuration

### Private Repositories

```bash
# Add repository via CLI
argocd repo add https://github.com/myorg/private-repo \
  --username myuser \
  --password mytoken

# Or via secret
oc create -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: rhdh
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/myorg/private-repo
  username: myuser
  password: mytoken
EOF
```

### Helm Repositories

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: helm-repo
  namespace: rhdh
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: helm
  name: stable
  url: https://charts.helm.sh/stable
  # Optional: for authenticated Helm repos
  username: myuser
  password: mypass
```

### Git Submodules

Enable Git submodules in repo server:

```yaml
spec:
  repo:
    env:
      - name: ARGOCD_GIT_MODULES_ENABLED
        value: "true"
```

---

## Application Sets

ApplicationSets enable managing multiple Applications as templates.

### List Generator Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices
  namespace: rhdh
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            url: https://kubernetes.default.svc
            namespace: dev
          - cluster: staging
            url: https://kubernetes.default.svc
            namespace: staging

  template:
    metadata:
      name: "{{cluster}}-guestbook"
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: guestbook
      destination:
        server: "{{url}}"
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Git Generator Example

Generate applications from Git repository structure:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
  namespace: rhdh
spec:
  generators:
    - git:
        repoURL: https://github.com/myorg/cluster-config
        revision: HEAD
        directories:
          - path: apps/*

  template:
    metadata:
      name: "{{path.basename}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/cluster-config
        targetRevision: HEAD
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{path.basename}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## Custom Health Checks

Define custom health assessments for CRDs.

### Resource Customization

```yaml
spec:
  resourceCustomizations: |
    # Custom health check for a CRD
    my.crd.group/MyResource:
      health.lua: |
        hs = {}
        if obj.status ~= nil then
          if obj.status.phase == "Running" then
            hs.status = "Healthy"
            hs.message = "Resource is running"
            return hs
          end
        end
        hs.status = "Progressing"
        hs.message = "Waiting for resource to be ready"
        return hs

    # Ignore differences for certain fields
    my.crd.group/MyResource:
      ignoreDifferences: |
        jsonPointers:
        - /status
```

### Known Types Configuration

```yaml
spec:
  resourceTrackingMethod: annotation

  resourceCustomizations: |
    # Ignore specific resource types
    ignoreDifferences: |
      - group: apps
        kind: Deployment
        jsonPointers:
        - /spec/replicas
```

---

## Notifications and Webhooks

### Configure Notifications

Create notification configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: rhdh
data:
  # Slack notification
  service.slack: |
    token: $slack-token

  # Email notification
  service.email.gmail: |
    username: $email-username
    password: $email-password
    host: smtp.gmail.com
    port: 465
    from: $email-username

  # Triggers
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]

  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]

  # Templates
  template.app-deployed: |
    message: Application {{.app.metadata.name}} is now running new version.
    slack:
      attachments: |
        [{
          "title": "{{.app.metadata.name}}",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "color": "good",
          "fields": [{
            "title": "Sync Status",
            "value": "{{.app.status.sync.status}}",
            "short": true
          }]
        }]
```

Create secret for tokens:

```bash
oc create secret generic argocd-notifications-secret \
  --from-literal=slack-token='xoxb-...' \
  -n rhdh
```

### Webhook Configuration

Configure webhooks in your Git provider to trigger syncs:

```bash
# Get webhook URL
ARGOCD_URL=$(oc get route argocd-server -n rhdh -o jsonpath='{.spec.host}')
echo "https://${ARGOCD_URL}/api/webhook"

# Configure in GitHub/GitLab:
# Payload URL: https://argocd-server-route/api/webhook
# Content type: application/json
# Secret: <your-webhook-secret>
```

---

## Backup and Restore

### Backup ArgoCD Configuration

```bash
#!/bin/bash
# backup-argocd.sh

NAMESPACE="rhdh"
BACKUP_DIR="argocd-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"

# Backup ArgoCD CR
oc get argocd argocd -n $NAMESPACE -o yaml > "$BACKUP_DIR/argocd-instance.yaml"

# Backup Applications
oc get applications -n $NAMESPACE -o yaml > "$BACKUP_DIR/applications.yaml"

# Backup ApplicationSets
oc get applicationsets -n $NAMESPACE -o yaml > "$BACKUP_DIR/applicationsets.yaml"

# Backup Projects
oc get appprojects -n $NAMESPACE -o yaml > "$BACKUP_DIR/projects.yaml"

# Backup Secrets (sanitize sensitive data)
oc get secrets -n $NAMESPACE -l argocd.argoproj.io/secret-type=repository -o yaml > "$BACKUP_DIR/repo-secrets.yaml"

# Backup ConfigMaps
oc get configmaps -n $NAMESPACE -l app.kubernetes.io/part-of=argocd -o yaml > "$BACKUP_DIR/configmaps.yaml"

echo "Backup saved to $BACKUP_DIR"
```

### Restore from Backup

```bash
#!/bin/bash
# restore-argocd.sh

BACKUP_DIR=$1
NAMESPACE="rhdh"

if [ -z "$BACKUP_DIR" ]; then
  echo "Usage: $0 <backup-directory>"
  exit 1
fi

# Restore in order
oc apply -f "$BACKUP_DIR/argocd-instance.yaml" -n $NAMESPACE
oc apply -f "$BACKUP_DIR/repo-secrets.yaml" -n $NAMESPACE
oc apply -f "$BACKUP_DIR/projects.yaml" -n $NAMESPACE
oc apply -f "$BACKUP_DIR/applications.yaml" -n $NAMESPACE
oc apply -f "$BACKUP_DIR/applicationsets.yaml" -n $NAMESPACE

echo "Restore complete"
```

### Disaster Recovery

For full disaster recovery, use a GitOps approach:

1. Store all ArgoCD Application manifests in Git
2. Use ApplicationSets for dynamic generation
3. Store ArgoCD instance configuration in Git (Infrastructure as Code)
4. Backup only repository credentials separately

---

## Monitoring and Metrics

### Prometheus Integration

Enable metrics exposure:

```yaml
spec:
  prometheus:
    enabled: true
    host: prometheus-operated.monitoring.svc
    port: 9090

  server:
    metrics:
      enabled: true

  repo:
    metrics:
      enabled: true

  controller:
    metrics:
      enabled: true
```

### ServiceMonitor for OpenShift Monitoring

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: rhdh
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
    - port: metrics
```

### Key Metrics to Monitor

| Metric                                | Description                   |
| ------------------------------------- | ----------------------------- |
| `argocd_app_info`                     | Application metadata          |
| `argocd_app_sync_total`               | Number of syncs               |
| `argocd_app_reconcile_count`          | Reconciliation count          |
| `argocd_app_k8s_request_total`        | K8s API requests              |
| `argocd_git_request_total`            | Git requests                  |
| `argocd_cluster_api_resource_objects` | Resources managed per cluster |
| `argocd_kubectl_exec_pending`         | Pending kubectl operations    |
| `argocd_redis_request_total`          | Redis requests                |

### Grafana Dashboard

Import the official ArgoCD Grafana dashboard:

Dashboard ID: `14584` (from grafana.com)

---

## Performance Optimization

### Cache Configuration

```yaml
spec:
  repo:
    env:
      # Enable cache
      - name: ARGOCD_REPO_CACHE_EXPIRATION
        value: "24h"
    # Increase cache size
    resources:
      limits:
        memory: 4Gi
```

### Increase Timeouts

```yaml
spec:
  controller:
    env:
      - name: ARGOCD_RECONCILIATION_TIMEOUT
        value: "300s"
      - name: ARGOCD_REPO_SERVER_TIMEOUT_SECONDS
        value: "180"

  repo:
    env:
      - name: ARGOCD_EXEC_TIMEOUT
        value: "300s"
      - name: ARGOCD_GIT_REQUEST_TIMEOUT
        value: "30s"
```

### Sharding

Distribute load across multiple controller instances:

```yaml
spec:
  controller:
    sharding:
      enabled: true
      replicas: 3
      # Optionally specify shard allocation
      dynamicShardingAlgorithm: "round-robin"
```

---

## Related Resources

- [ArgoCD Operator Manual](https://argo-cd.readthedocs.io/en/stable/operator-manual/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD Troubleshooting Guide](./argocd-troubleshooting.md)
- [ArgoCD Plugin Documentation](../docs/argocd.md)
