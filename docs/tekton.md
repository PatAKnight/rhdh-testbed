# Plugin: backstage-community-plugin-tekton

## Description

The Tekton plugin allows RHDH to visualize and track CI/CD workflows defined and run using Tekton Pipelines. This plugin integrates tightly with OpenShift Pipelines to surface `PipelineRuns`, `Tasks`, `Pipelines`, and their statuses inside the RHDH UI.

---

## How to Configure

You can enable this plugin in two ways: manually or automatically via scripts provided in this repo.

### Manual Setup

To manually configure this plugin:

1. Install OpenShift Pipelines Operator
   - Install the operator in your target namespace using OperatorHub.
2. Deploy Tekton Resources
   - Create a `Pipeline` and a corresponding `PipelineRun` in your OpenShift namespace.
   - Example resources can be found under;
     `resources/tekton/hello-world-pipeline-run.yaml`
     `resources/tekton/hello-world-pipeline.yaml`
3. Ensure that the `backstage-plugin-kubernetes` plugins have been configured and enabled
   - The following `customResources` is added in the `app-config.yaml

   ```YAML
   kubernetes:
     ...
     customResources:
       - apiVersion: v1beta1
         group: tekton.dev
         plural: pipelines
       - apiVersion: v1beta1
         group: tekton.dev
         plural: pipelineruns
       - apiVersion: v1beta1
         group: tekton.dev
         plural: taskruns
   ```

---

### Automatic Setup

Automated setup is available in two levels depending on how much you want configured for you.

#### Everything

Runs the root-level script to:

- Install the OpenShift Pipelines Operator.
- Deploy example `Pipeline` and `PipelineRun`
- Set any required secrets or RBAC policies for access the Tekton plugin.

**Run:**

```bash
./start.sh
```

#### Just the Integration

Run only the integration script:

**Run:**

```bash
./scripts/config-tekton-plugin.sh
```

This script performs:

- OpenShift Pipelines Operator installation.
- Deployment of example Tekton resources (`Pipeline`, `PipelineRun`)

This is useful if you already have a Backstage instance up and want to bolt on just the Tekton integration.

## Demo

1. Open RHDH and navigate to the catalog.
2. Open a software entity that includes the `backstage.io/kubernetes-id` and `tekton.dev/cicd` annotations.
   - The `developer-hub` entity could be used for demo purposes in the event that the root script was used.
3. Go to the `CI/CD` tab to view the status of the `PipelineRun`
4. Clicking into the `PipelineRun` will show a visualization of that particular `PipelineRun`

## Related Files

- Resources: `resources/tekton/` - Tekton CRs and supporting manifests, `resources/operators/` - OpenShift Pipelines operator subscription
- Scripts: `scripts/config-tekton-plugin.sh` - Automates plugin setup

## Notes

- The Kubernetes plugin must be configured before using the Tekton plugin, as Tekton relies on the Kubernetes integration to fetch pipeline data.
- Entities must have the `backstage.io/kubernetes-id` annotation to display Tekton data.
