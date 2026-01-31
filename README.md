# rhdh-testbed

A collection of resources and scripts to quickly deploy an RHDH instance in Kubernetes, preloaded with useful plugins, example entities, and third-party integrations for rapid testing and development.

## Table of Contents

- [Background and Purpose](#background-and-purpose)
- [Outline of this project](#outline-of-this-project)
- [Running the Scripts](#running-the-scripts)
  - [Option 1: Local Installation](#option-1-local-installation)
  - [Option 2: Run with Docker](#option-2-run-with-docker)
  - [Option 3: Deploy as Kubernetes Job](#option-3-deploy-as-kubernetes-job)
- [Next Steps](#next-steps)
- [General notes](#general-notes)

## Background and Purpose

These scripts were created out of a need to quickly spin up an RHDH instance preconfigured for testing. The goal is to streamline the process of deploying Red Hat Developer Hub with preconfigured plugins and supporting resources, making it easy for team members, especially those working on plugins, to verify changes, report bugs, and explore features in a real environment. It also serves as a practical example of how RHDH and its plugins can be integrated and showcased.

### What the Script Does

The RHDH Start-Up Script is designed to launch an RHDH instance with a selected set of plugins and supporting resources. Its goals are:

- To reduce the manual work of configuring plugins and their integration points
- To create an environment well-suited for various testing scenarios
- To demonstrate the capabilities of RHDH and its bundled plugins

It also deploys companion resources that are registered into the catalog, making it useful as a standalone demo environment.

### Intended Usage and Environment

These scripts are tailored for OpenShift clusters, ideally short-lived or non-production environments like:

- OpenShift Local (CRC)
- Cluster Bot clusters

They may work on other Kubernetes platforms, but this hasn't been tested or verified. At the time of writing, most of my testing has been performed using Cluster bot.

**Important** Running this script will install several components and operators, included Red Hat SSO, Advance Cluster Management, OpenShift GitOps, and more. It will also create service accounts and other cluster-level resources. For this reason, it is strongly recommended to use a disposable or non-critical cluster. Before running the scripts, you should review the resources being deployed. Additional documentation is provided to walk through the steps taken for setting up specific plugin configurations.

## Outline of this project

This project includes a collection of scripts and Kubernetes resources designed to streamline the deployment and testing of an RHDH instance. The structure and tooling are intended to offer both an out-of-the-box experience and the flexibility to customize plugin configurations.

### `start.sh`: RHDH Setup Script

The main setup script (`start.sh`) is used to:

- Launch an RHDH instance
- Deploy a variety of preconfigured Kubernetes resources that integrate with RHDH
- Optionally configure additional plugins and integrations

By default, the script is designed to work "out of the box" on first run, creating a working RHDH environment with minimal effort. Follow-up runs can be used to customize the setup further or to selectively configure only specific components. For users who prefer full control from the beginning, it's also possible to bypass the initial setup and tailor the configuration to specific needs. This versatility is intentional and core to the project's design.

### `teardown.sh`: RHDH Cleanup Script

The teardown script (`teardown.sh`) is used to:

- Clean up the RHDH instance and all associated resources
- Free up compute resources for redeploying a different plugin set or environment configuration

This script removes nearly everything created by the setup process, except for the namespace itself, allowing for quick redeployment into the same logical space.

### Plugin Demo Resources

A set of Kubernetes resources are included to support demoing various RHDH plugins. These resources are:

- Preconfigured for ease of use
- Intended to simplify setup for plugin features like GitOps, SSO, etc.

Some additional configuration may be required for smooth deployment, which is detailed in the plugin specific documentation

### `/auth`: Auth and Integration Credentials

The `/auth` directory is intended to store sensitive configuration files used by various plugins, an example being the GitHub App credentials used for authentication and catalog ingestion. While these values could be set via environment variables, storing them in a centralized directory:

- Keeps credential files easy to reference and manage
- Supports manual plugin configuration outside of the automated script flow

More details about this directory and how to populate it are provided in the plugin specific documentation.

## Running the Scripts

There are three ways to run the testbed scripts, depending on your environment and preferences:

| Method                                                   | Best For                                                | Requirements                   |
| -------------------------------------------------------- | ------------------------------------------------------- | ------------------------------ |
| **[Local](#option-1-local-installation)**                | Development, quick iterations, full control             | `oc`, `helm` installed locally |
| **[Docker Compose](#option-2-run-with-docker)**          | macOS users, isolated environment, no local tool setup  | Docker Desktop                 |
| **[Kubernetes Job](#option-3-deploy-as-kubernetes-job)** | CI/CD pipelines, fully automated, no local tools needed | Cluster access only            |

### Option 1: Local Installation

These scripts are designed to work out-of-the-box with minimal setup. In fact, it's recommended that you start with the default setup to better understand how everything fits together. You can always customize and extend things later.

### Requirements

- `oc` OpenShift CLI
- `helm`

Step 1. Fork and clone this repo:

```bash
git clone https://github.com/PatAKnight/rhdh-testbed.git
cd rhdh-testbed
```

Step 2. Ensure access to an OpenShift Cluster:

- These scripts rely on `oc` and `helm` to manage the resources for you, so an OpenShift cluster is a must.

**Important**: Most testing has been done using Cluster Bot

Step 3. Configure Your Environment by creating you local `.env` file by copying the provided sample:

```bash
cp .env.sample .env
```

Step 4. Open the `.env` and set at least the following three values obtained from your cluster:

```env
K8S_CLUSTER_TOKEN=<your-cluster-token>
K8S_CLUSTER_URL=<your-cluster-api-url>
K8S_CLUSTER_NAME="test-cluster"

SIGN_IN_PAGE="guest"
```

Step 5. Run the script:

```bash
./start.sh
```

Step 6. Access your RHDH instance:

- Once deployment is complete, navigate to the exposed route for RHDH in your OpenShift cluster (this is typically displayed in the script output).

You'll now have a clean, working instance of RHDH that's ready to be enhanced in the next steps

## Option 2: Run with Docker

If you prefer containerized execution, use this instead of the local installation above:

- Prereqs: Docker, `.env` configured (see Steps 3–4 from local installation).
- First time setup:

```bash
docker compose build
docker compose up rhdh-start
```

- Teardown when done:

```bash
docker compose up rhdh-teardown
```

## Option 3: Deploy as Kubernetes Job

For fully automated, hands-off deployment directly on your cluster without any local tooling requirements, you can deploy the testbed as a Kubernetes Job.

### Prerequisites

- Access to an OpenShift cluster with `cluster-admin` or equivalent permissions
- `oc` or `kubectl` CLI (only needed to apply the manifests)

### Using the Pre-built Image

A pre-built container image is available at `ghcr.io/PatAKnight/rhdh-testbed:latest`.

**Step 1.** Create the deployment namespace:

`oc new-project rhdh-testbed`

**Step 2a.** Configure the deployment by editing `deploy/configmap.yaml`:

Key ConfigMap values:

| Variable         | Description                           | Default    |
| ---------------- | ------------------------------------- | ---------- |
| NAMESPACE        | Namespace where RHDH will be deployed | rhdh       |
| RELEASE_NAME     | Helm release name                     | backstage  |
| K8S_CLUSTER_NAME | Name for you cluster in RHDH          | my-cluster |
| SIGN_IN_PAGE     | Authentication method (guest or oidc) | guest      |

> **Note:** Plugin enablement is configured via the dynamic plugins ConfigMap (see Step 2c below), not through environment variables

**Step 2b.** Create your secret file using `deploy/secret-template.yaml` as an example:

```bash
# Step 2b: Create and apply your secret
cp deploy/secret-template.yaml deploy/secret.local.yaml

# Edit with your values THEN APPLY
oc apply -f deploy/secret.local.yaml -n rhdh-testbed
```

**Step 2c.** Configure dynamic plugins:

The testbed detects which plugins you've enabled in your `dynamic-plugins-config.yaml` and automatically deploys any required cluster resources (operators, CRDs, etc.).

**Option A**: Use the default configuration (simplest)

If you don't need custom plugins, the pre-included configuration works out of the box:

```bash
# Create ConfigMap from the default dynamic plugins config
oc create configmap rhdh-dynamic-plugins \
  --from-file=dynamic-plugins.yaml=resources/rhdh/dynamic-plugins-config.yaml \
  -n rhdh-testbed
```

**Option B**: Customize which plugins are enabled

For more control over which plugins and operators are deployed:

```bash
# Copy the default config
cp resources/rhdh/dynamic-plugins-config.yaml my-plugins-config.yaml

# Edit to enable/disable plugins by setting disabled: false/true
# For example, to enable Keycloak SSO:
#   - package: ./dynamic-plugins/dist/backstage-community-plugin-catalog-backend-module-keycloak-dynamic
#     disabled: false  # Change from true to false

# Create ConfigMap from your customized config
oc create configmap rhdh-dynamic-plugins \
  --from-file=dynamic-plugins.yaml=my-plugins-config.yaml \
  -n rhdh-testbed
```

Plugins that trigger cluster resource deployment:

| Plugin Pattern                         | What Gets Deployed                    |
| -------------------------------------- | ------------------------------------- |
| plugin-catalog-backend-module-keycloak | Red Hat SSO Operator + Keycloak Realm |
| plugin-tekton                          | OpenShift Pipelines Operator          |
| plugin-ocm / plugin-ocm-backend        | Advanced Cluster Management Operator  |
| plugin-3scale-backend                  | 3scale Operator + API Manager         |
| plugin-kubernetes / plugin-topology    | ServiceAccount token configuration    |

> **Work in Progress:** Not all plugins require cluster resources, and not all plugins that do require resources have been integrated into the automation scripts yet. If you enable a plugin that needs additional setup (like an operator), check the `docs/` folder for manual configuration steps or open an issue if support is missing.

**Step 3.** Apply the deployment resources:

```bash
# Apply ServiceAccount, ClusterRole, ClusterRoleBinding, ConfigMap, and Secret
oc apply -k deploy/

# Verify the dynamic plugins ConfigMap was created (from Step 2c)
oc get configmap rhdh-dynamic-plugins -n rhdh-testbed

# Start the setup job
oc apply -f deploy/job.yaml
```

> **Note:** The Job mounts the `rhdh-dynamic-plugins` ConfigMap to `/app/resources/user-resources/dynamic-plugins-config.local.yaml`. The setup script reads this to determine which cluster resources to deploy.

**Optional Step** Monitor the deployment:

```bash
# Watch the job status
oc get jobs -n rhdh-testbed -w

#View logs
oc logs -f job/rhdh-testbed-setup -n rhdh-testbed
```

**Step 4.** Access your RHDH instance:

Once the job completes, the RHDH route URL will be displayed in the logs.

### Teardown

To clean up the RHDH deployment

```bash
# Delete the setup job first
oc delete job rhdh-testbed-setup -n rhdh-testbed

# Run the teardown job
oc apply -f deploy/teardown-job.yaml

# Option: Watch teardown progress
oc logs -f job/rhdh-testbed-teardown -n rhdh-testbed
```

### Building Your Own Image

If you want to customize the scripts or use your own container registry:

**Step 1.** Build the image:

`docker build -t your-registry/rhdh-testbed:latest .`

**Step 2.** Push to your registry:

`docker push your-registry/rhdh-testbed:latest`

**Step 3.** Update the job manifests to user your image:

```yaml
# Edit deploy/job.yaml and deploy/teardown-job.yaml
# Change the image reference:
#   image: ghcr.io/pataknight/rhdh-testbed:latest
# To:
#   image: your-registry/rhdh-testbed:latest
```

Alternatively, use kustomize to override the image:

```bash
cd deploy
kustomize edit set image ghcr.io/pataknight/rhdh-testbed:latest=your-registry/rhdh-testbed:v1.0.0
oc apply -k .
```

### Building the Image In-Cluster (Optional)

If you prefer to build the image directly in OpenShift instead of using the pre-built image from ghcr.io:

**Step 1.** Create the namespace and apply the BuildConfig:

```bash
oc new-project rhdh-testbed
oc apply -f deploy/build-config.yaml
```

**Step 2.** Start the build and wait for completion:

`oc start-build rhdh-testbed -n rhdh-testbed --follow`

**Step 3.** Apply the remaining resources and use the internal registry job:

```bash
oc apply -k deploy/
oc apply -f deploy/job-internal-registry.yaml
```

### Teardown

To clean up the RHDH deployment

```bash
# Delete the setup job first
oc delete job rhdh-testbed-setup -n rhdh-testbed

# Run the teardown job
oc apply -f deploy/teardown-job-internal-registry.yaml

# Option: Watch teardown progress
oc logs -f job/rhdh-testbed-teardown -n rhdh-testbed
```

\*\*Benefits of building in-cluster:

- No external registry access required
- Full visibility into build process and logs
- Easy to customize by forking the repo and updating the BuildConfig git URL
- Image stays within your cluster's trust boundary

**To use you own fork:**

Edit `deploy/buildconfig.yaml` and change the git URI:

```yaml
spec:
  source:
    git:
      uri: https://github.com/YOUR-USERNAME/rhdh-testbed.git
      ref: main # or your branch
```

### Security Considerations

The Kubernetes Job requires elevated permissions to:

- Create namespaces and projects
- Install Operators via OLM
- Create ClusterRoles and ClusterRoleBindings
- Deploy various workloads and CRDs

**This tool is designed for disposable, non-production clusters.** The included ClusterRole grants broad permissions necessary for the automation. Always review `deploy/cluster-role.yaml` before applying.
The Job uses a dedicated ServiceAccount (`rhdh-testbed-runner`) that is scoped to only what's necessary for the deployment automation.

## Next Steps

So, you now have a running RHDH (Red Hat Developer Hub) instance, great! But this base setup is just the foundation. To transform it into a useful demo or testing environment, here are some next steps to take:

### Understanding the Generated Resources

During setup, a number of editable resources are created under `resources/user-resources/`. These are designed for customization and extension.

- `resources/user-resources/app-config` - Stores application configuration
- `resources/user-resources/rbac-policy` - Contains RBAC policy definitions used to manage user permissions.
- `resources/user-resources/rhdh-secrets` - Holds required secrets like credentials and tokens
  **Note:** This file is auto-generated, avoid editing manually unless necessary. Changes could be overwritten.
- `resources/user-resources/dynamic-plugins` - Controls which dynamic plugins are enabled and their configurations.

### Enabling Additional Plugins

The testbed uses the standard RHDH `dynamic-plugins.default.yaml format for plugin configuration. To enable a plugin:

1. **Edit the dynamic plugins config file:**
   - Local runs: `resources/user-resources/dynamic-plugins-config.local.yaml`
   - Kubernetes Job: Create a ConfigMap (see [Option 3](#option-3-deploy-as-kubernetes-job))

2. **Set `disabled: false`** on the plugin(s) you want:
   - package: ./dynamic-plugins/dist/backstage-community-plugin-tekton
     disabled: false # Change from true to false

3. Re-run the setup to apply changes:
   - Local: `./start.sh`
   - Docker: `docker compose up rhdh-start`
   - Kubernetes Job: Delete the existing job and recreate it

### Using the Instance as a Demo Environment

Each plugin includes demo guidance and sample scenarios to help showcase its features in a meaningful way.

- Plugin documentation within this project includes a Demo section
- Many plugins and integrations include sample data, configurations, or actions that simulate real-world usage.
- These examples are designed to create a richer, interactive experience for testing and presentation.

## General notes

- There are a number of resources included in this project, I was aiming to make it require as little configuration as possible, as such it isn't recommended to make changes to k8s resources themselves. Ideally, just the `user-resources` should be updated (minus the `rhdh-secrets`).
- A number of credentials are meant to be stored to make access easier, included is a `.gitIgnore` that will ignore any yaml files containing `.local.yaml` to hopefully prevent accidental leaks, still be mindful of anything that you add to this project.
  - This also doubles in that if you wish to contribute any changes / enhancements to the project, you do not have to worry about reverting / removing credentials and secrets
- Following up from that, contributions are welcome. This was definitely a learning experience for me which translates to there are more than likely much better (and probably simpler) ways to accomplish what I did.
