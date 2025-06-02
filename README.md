# rhdh-testbed

A collection of resources and scripts to quickly deploy an RHDH instance in Kubernetes, preloaded with useful plugins, example entities, and third-party integrations for rapid testing and development.

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

## First Steps

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

To add new functionality:

1. Review the plugin documentation
   Understand what the plugin does, its purpose, and any required configuration.

2. Enable the plugin
   Edit `resources/user-resources/dynamic-plugins-config.yaml` and add or update the desired plugin entry.

3. Meet plugin requirements
   Ensure any required credentials, secrets, or environment variables are set appropriately.

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
