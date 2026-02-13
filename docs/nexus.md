# Plugin: @janus-idp/backstage-plugin-nexus-repository-manager

## Description

The Nexus Repository Manager plugin integrates Sonatype Nexus Repository Manager with Red Hat
Developer Hub (RHDH), allowing you to view and manage artifacts stored in Nexus directly from the
Backstage catalog. This plugin provides visibility into Maven, npm, Docker, and other artifact
repositories, making it easier for developers to discover and use published artifacts.

Key features:

- View artifact information and metadata
- Browse repository contents
- Display artifact versions and download statistics
- Link artifacts to their corresponding components in the catalog

---

## How to Configure

You can configure this plugin either manually or automatically using the provided scripts.

### Manual Setup

1. Deploy required infrastructure:
   - Install the Nexus Repository Manager Operator (community operator).
   - Deploy a `NexusRepo` custom resource to create a Nexus instance.
   - Wait for the Nexus instance to be ready and obtain the URL and credentials.

2. Configure RHDH integration:
   - Enable the Nexus Repository Manager plugin in your dynamic plugins configuration with proper
     proxy settings.
   - The plugin uses a **frontend proxy** to communicate with Nexus (not backend environment
     variables).
   - Add this configuration to your `dynamic-plugins-configmap.yaml`:

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
               target: "https://${NEXUS_URL}"
               headers:
                 X-Requested-With: "XMLHttpRequest"
                 # For authenticated access (recommended):
                 Authorization: "Basic ${NEXUS_AUTH_HEADER}"
               changeOrigin: true
               # Set to false if using self-signed certificates
               secure: true
     ```

   - **Important**: The plugin requires a proxy configuration because it's a frontend plugin that
     calls Nexus from the browser.
   - The `target` should be your Nexus URL (without `/api` or other paths)
   - For authentication, use a Base64-encoded `username:password` in the Authorization header

3. Configure authentication:
   - Generate the auth header value: `echo -n "admin:<your-password>" | base64`
   - Add to your secrets:

     ```yaml
     NEXUS_URL: "https://nexus-repo-route.example.com"
     NEXUS_AUTH_HEADER: "<BASE64_ENCODED_CREDENTIALS>"
     ```

4. Add annotations to catalog entities:
   - Add the following annotations to your component's `catalog-info.yaml`:

     ```yaml
     metadata:
       annotations:
         # For Maven artifacts
         nexus-repository-manager/repository: maven-releases
         nexus-repository-manager/maven.group-id: com.example
         nexus-repository-manager/maven.artifact-id: my-app
         nexus-repository-manager/maven.base-version: 1.0.0
     ```

   - See the
     [full list of available annotations](https://github.com/backstage/community-plugins/blob/main/workspaces/nexus-repository-manager/plugins/nexus-repository-manager/ANNOTATIONS.md).

---

### Automatic Setup

Automated setup is available in two levels depending on how much you want configured for you.

#### Everything

Runs the root-level script to deploy the complete infrastructure including Nexus Repository Manager.
Requires the Nexus plugin to be enabled by setting `disabled: false` in your dynamic plugins
configuration.

**Run:**

```bash
./start.sh
```

#### Just the Integration

Only configures the integration resources for this plugin. Use this if you already have a Backstage
instance running and just need this plugin.

**Run:**

```bash
./scripts/config-nexus-plugin.sh
```

This script will:

- Install the Nexus Repository Manager Operator
- Deploy a Nexus Repository Manager instance
- Configure secrets for RHDH authentication (`NEXUS_URL` and `NEXUS_AUTH_HEADER`)
- Apply Kubernetes labels for topology view
- Populate demo data (Maven and npm artifacts)
- Register demo catalog entities

**Important - Manual Step Required:**

After running the script, you must **add the proxy configuration** to your
`dynamic-plugins-configmap.yaml`:

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
          secure: true # Set to false if using self-signed certificates
```

The setup script automatically generates the `NEXUS_URL` and `NEXUS_AUTH_HEADER` environment
variables and stores them in the `rhdh-secrets` secret. The proxy configuration above references
these variables.

**Why proxy configuration?**

- The Nexus plugin is a **frontend plugin** (runs in the browser)
- RHDH's backend acts as a proxy to avoid CORS issues and handle authentication
- The proxy forwards requests from `/api/nexus-repository-manager/*` to your Nexus instance

---

## Demo

1. Go to your RHDH instance.
2. Navigate to the Catalog.
3. Open a component that has Nexus annotations.
4. Look for the "Nexus Repository Manager" tab or card.
5. View the artifact information, versions, and repository details.

Alternatively:

1. Access the Nexus web UI directly at the route created in your namespace.
2. Login with admin credentials (check the `nexus-admin-credentials` secret).
3. Browse the repositories and verify demo artifacts are present.

---

## Demo Data

This plugin includes test resources to demonstrate functionality:

### Demo Artifacts

- **Sample Maven Artifact**: `com.example.demo:hello-world-lib:1.0.0` - A simple Java library JAR
  with POM file
- **Sample npm Package**: `@demo/hello-world@1.0.0` - A basic Node.js package demonstrating npm
  repository

### Demo Catalog Entities

The setup automatically registers demo components in the RHDH catalog:

- **hello-world-lib** (Component) - Maven library with Nexus annotations
  - Repository: `maven-releases`
  - Maven Group ID: `com.example.demo`
  - Maven Artifact ID: `hello-world-lib`
  - Maven Base Version: `1.0.0`
  - Owner: `group:default/guardians-of-the-galaxy`

- **hello-world-npm** (Component) - npm package with Nexus annotations
  - Repository: `npm-internal`
  - Name: `@demo/hello-world`
  - npm Scope: `@demo`
  - Owner: `group:default/x-men`

These catalog entities use existing Keycloak teams for ownership, enabling RBAC testing. Different
users will see different components based on their team membership:

- Users in the Guardians of the Galaxy team will see the Maven library
- Users in the X-Men team will see the npm package
- Cluster admins will see all components

These catalog entities showcase how to use the Nexus Repository Manager plugin annotations in your
own components.

### Configuration

Demo data is automatically populated during setup. To disable:

```bash
export POPULATE_DEMO_DATA=false
./scripts/config-nexus-plugin.sh
```

To manually populate demo data after deployment:

```bash
oc apply -f resources/nexus/populate-demo-data-job.yaml -n rhdh
```

To manually register catalog entities:

```bash
oc create configmap nexus-demo-entities-config-map \
  --from-file=demo-nexus-artifacts.yaml=resources/nexus/demo-catalog-entities.yaml \
  -n rhdh

oc label configmap nexus-demo-entities-config-map \
  backstage.io/kubernetes-id=developer-hub -n rhdh
```

---

## Accessing Nexus

### Web UI

Get the Nexus URL and login:

```bash
# Get the URL
echo "https://$(oc get route nexus-repo -n rhdh -o jsonpath='{.spec.host}')"

# Get admin password
oc get secret nexus-admin-credentials -n rhdh -o jsonpath='{.data.password}' | base64 -d
echo ""
```

Default username: `admin`

### REST API

You can interact with Nexus programmatically:

```bash
NEXUS_URL=$(oc get route nexus-repo -n rhdh -o jsonpath='{.spec.host}')
NEXUS_PASS=$(oc get secret nexus-admin-credentials -n rhdh -o jsonpath='{.data.password}' | base64 -d)

# Check status
curl -u admin:${NEXUS_PASS} https://${NEXUS_URL}/service/rest/v1/status

# List components in a repository
curl -u admin:${NEXUS_PASS} https://${NEXUS_URL}/service/rest/v1/components?repository=maven-releases
```

---

## Available Repositories

After deployment, Nexus comes pre-configured with:

| Repository      | Type   | Purpose                                     |
| --------------- | ------ | ------------------------------------------- |
| maven-releases  | hosted | Release artifacts for Maven (includes demo) |
| maven-snapshots | hosted | Snapshot artifacts for Maven                |
| maven-central   | proxy  | Proxy to Maven Central                      |
| npm-internal    | hosted | Private npm packages (includes demo)        |
| npm-proxy       | proxy  | Proxy to npmjs.org                          |
| docker-hosted   | hosted | Private Docker images                       |
| docker-proxy    | proxy  | Proxy to Docker Hub                         |

---

## Quick Verification

After deployment, verify everything is working:

```bash
# 1. Check operator is installed
oc get csv -n rhdh | grep nxrm-operator

# 2. Check Nexus instance is running
oc get nexusrepo nexus-repo -n rhdh

# 3. Check demo data job completed
oc get job nexus-populate-demo-data -n rhdh

# 4. Check catalog entities are registered
oc get configmap nexus-demo-entities-config-map -n rhdh

# 5. Verify demo artifacts in Nexus
NEXUS_URL=$(oc get route nexus-repo -n rhdh -o jsonpath='{.spec.host}')
NEXUS_PASS=$(oc get secret nexus-admin-credentials -n rhdh -o jsonpath='{.data.password}' | base64 -d)
curl -u admin:${NEXUS_PASS} https://${NEXUS_URL}/service/rest/v1/components?repository=maven-releases
```

---

## Related Files

- `/scripts/config-nexus-plugin.sh` - Automates plugin setup
- `/resources/nexus/` - Nexus CRs and supporting manifests
- `/resources/nexus/nexus-repo.yaml` - Nexus Repository Manager instance definition
- `/resources/nexus/populate-demo-data-job.yaml` - Demo data population job
- `/resources/nexus/demo-catalog-entities.yaml` - Demo catalog entities with Nexus annotations
- `/resources/operators/nexus-subscription.yaml` - Nexus operator subscription

---

## Additional Resources

For more detailed information:

- [Nexus Troubleshooting Guide](../guides/nexus-troubleshooting.md) - Common issues and solutions
- [Nexus Advanced Configuration](../guides/nexus-advanced-config.md) - Production setup,
  persistence, performance tuning

---

## Notes

- The Nexus Repository Manager Operator is a community operator and is available in the OperatorHub.
- The default installation uses ephemeral storage. For production use, configure persistent volume
  claims.
- Initial admin password can be retrieved from the `nexus-admin-credentials` secret.
- The plugin supports multiple repository formats: Maven, npm, Docker, PyPI, RubyGems, and more.
- Initial Nexus startup may take 2-3 minutes.
