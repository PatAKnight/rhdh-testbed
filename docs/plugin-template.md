# Plugin: <Plugin Name>

## Description

<Brief description of what this plugin does. Mention its purpose, key features, and any notable integrations it enables.>

Example:

> Enables GitHub integration for Backstage, including catalog ingestion and scaffolder support. Useful for teams managing software components in GitHub.

---

## How to Configure

You can configure this plugin either manually or automatically using the provided scripts.

### Manual Setup

<Outline the manual steps needed to enable this plugin. This may include:>
- Installing dependencies
- Creating secrets or configmaps
- Editing Backstage config
- Restarting the Backstage app

Example:

1. Create GitHub App
2. Create Kubernetes secrets for the credentials
3. Update `app-config.yaml` with the provider details
4. Restart Backstage

---

### Automatic Setup

Automated setup is available in two levels depending on how much you want configured for you.

#### Everything

Runs the root-level script to:

- Deploy Backstage (if not already deployed)
- Enable this plugin
- Deploy all necessary integration resources

**Run:**

```bash
./start.sh
```

#### Just the Integration

Only configures the integration resources for this plugin. Use this if you already have a Backstage instance running and just need this plugin.

**Run:**

```bash
./scripts/<plugin-script>.sh
```

## Demo

<Describe or link to a demo flow that verifies the plugin is working. This can be a test entity, UI behavior, or CLI output.>

Example:

1. Visit the Backstage Catalog
2. Check for GitHub-based components
3. Use the "Create Component" flow to scaffold a project from GitHub

## Related Files

- `/scripts/<plugin-script>.sh`
- `/resources/<plugin-name>/`
- `/auth/<relevant-credentials-if-any>`

## Notes

<Optional section for warnings, caveats, known issues, or tips.>

- Make sure your cluster has internet access if pulling public Helm charts
- Some plugins require manual GitHub/GitLab setup prior to script execution
