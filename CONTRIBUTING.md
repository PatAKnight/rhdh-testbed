# Contributing to RHDH Testbed

Thank you for your interest in contributing to the RHDH Testbed project! This guide will help you get started.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Adding New Plugins](#adding-new-plugins)
  - [Using Cursor IDE (Recommended)](#using-cursor-ide-recommended)
  - [Manual Approach](#manual-approach)
- [Code Conventions](#code-conventions)
- [Submitting Changes](#submitting-changes)
- [Documentation](#documentation)

## Getting Started

Before contributing, please:

1. Familiarize yourself with the [README](README.md) to understand the project's purpose
2. Review existing [issues](https://github.com/PatAKnight/rhdh-testbed/issues) to avoid duplicating work
3. Check the `docs/` folder for plugin-specific documentation

## Development Setup

### Prerequisites

- Access to an OpenShift cluster (disposable/non-production recommended)
- `oc` CLI installed and configured
- `helm` CLI installed
- Bash shell

### Local Development

1. Clone the repository:

   ```bash
   git clone https://github.com/PatAKnight/rhdh-testbed.git
   cd rhdh-testbed
   ```

2. Copy the sample environment file:

   ```bash
   cp .env.sample .env
   ```

3. Edit `.env` with your cluster credentials and configuration

4. Run the setup:

   ```bash
   ./start.sh
   ```

### Testing Changes

- Test your changes against a disposable OpenShift cluster
- Run `./teardown.sh` to clean up resources after testing
- Verify that both setup and teardown complete without errors

## Adding New Plugins

When adding support for a new RHDH plugin, you'll need to create several components. You can use the Cursor IDE with our scaffolding rule for guided assistance, or follow the manual checklist below.

### Using Cursor IDE (Recommended)

If you're using [Cursor IDE](https://cursor.sh/), this repository includes a scaffolding rule that provides guided assistance when adding new plugins.

#### How It Works

The rule at `.cursor/rules/plugin-scaffolding.mdc` automatically activates when you're working with:

- `scripts/config-*-plugin*.sh` files
- `resources/**/` directories
- `docs/*.md` files
- `config-plugins.sh`

#### Getting Started with Cursor

1. Open the repository in Cursor IDE

2. Start a new chat and ask Cursor to help add a plugin:

   ```
   I want to add support for the <plugin-name> plugin. Can you help me scaffold the necessary files?
   ```

3. Cursor will guide you through creating:
   - Documentation file
   - Configuration script with proper functions
   - Resource manifests (if needed)
   - Updates to `config-plugins.sh`
   - Secret template updates

#### Example Prompts

- "Add support for the Ansible plugin to this project"
- "Create scaffolding for integrating the Quay plugin"
- "Help me add the SonarQube plugin with operator deployment"

The rule includes templates, checklists, and examples to ensure consistency with existing plugins.

---

### Manual Approach

If you're not using Cursor, follow this checklist:

#### Required Files

| File                                     | Purpose                        |
| ---------------------------------------- | ------------------------------ |
| `docs/<plugin-name>.md`                  | Documentation for the plugin   |
| `scripts/config-<plugin-name>-plugin.sh` | Configuration script           |
| `resources/<plugin-name>/`               | Resource manifests (if needed) |

#### Required Updates

1. **`config-plugins.sh`** - Add entries to:
   - `PACKAGE_TO_CATEGORY` - Map package names to categories
   - `CATEGORY_SETUP_FUNCTIONS` - Define setup functions
   - `CATEGORY_TEARDOWN_FUNCTIONS` - Define teardown functions

2. **`resources/rhdh/rhdh-secrets.yaml`** - Add secret placeholders

3. **`deploy/secret-template.yaml`** - Add secret placeholders

4. **`.env.sample`** - Add any user-provided variables

#### Plugin Script Template

Your configuration script should follow this structure:

```bash
#!/bin/bash

deploy_<plugin>() {
  # Deploy operators/prerequisites
}

deploy_<plugin>_resources() {
  # Deploy plugin-specific resources
}

config_secrets_for_<plugin>_plugins() {
  # Configure secrets in rhdh-secrets.local.yaml
}

apply_<plugin>_labels() {
  # Apply backstage.io/kubernetes-id labels
}

uninstall_<plugin>() {
  # Cleanup for teardown
}

main() {
  source "${PWD}/env_variables.sh"
  source "${PWD}/.env"

  deploy_<plugin>
  deploy_<plugin>_resources
  config_secrets_for_<plugin>_plugins
  apply_<plugin>_labels
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
```

#### Plugin Guidelines

- **License-free**: Only include resources for services that can run without commercial licenses
- **Self-contained**: Plugins should work within a single cluster without external dependencies
- **Demo-ready**: Focus on demo/testing use cases, not production deployments

## Code Conventions

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include a header comment describing the script's purpose
- Use meaningful function names: `deploy_*`, `config_*`, `uninstall_*`
- Source `env_variables.sh` and `.env` in the `main()` function
- Use `${VARIABLE}` syntax for variable expansion
- Quote variables to prevent word splitting: `"${NAMESPACE}"`

### YAML Files

- Use 2-space indentation
- Include comments explaining non-obvious configurations
- Use `---` to separate multiple documents in a single file

### Naming Conventions

| Type       | Convention                  | Example                   |
| ---------- | --------------------------- | ------------------------- |
| Scripts    | `config-<plugin>-plugin.sh` | `config-tekton-plugin.sh` |
| Docs       | `<plugin>.md`               | `tekton.md`               |
| Resources  | `resources/<plugin>/`       | `resources/tekton/`       |
| Categories | `UPPERCASE`                 | `TEKTON`, `KEYCLOAK`      |

## Submitting Changes

### Pull Request Process

1. Create a feature branch from `main`:

   ```bash
   git checkout -b feature/add-<plugin>-support
   ```

2. Make your changes following the conventions above

3. Test your changes thoroughly

4. Commit with a descriptive message:

   ```bash
   git commit -m "Add support for <plugin> plugin"
   ```

5. Push and create a pull request

### PR Requirements

- [ ] All new scripts are executable (`chmod +x`)
- [ ] Documentation is included for new plugins
- [ ] `config-plugins.sh` is updated with new mappings
- [ ] Secret templates are updated if needed
- [ ] Changes tested against a real cluster
- [ ] No secrets or credentials committed

### What to Avoid

- **Do not commit secrets** - Use `.env` (gitignored) for credentials
- **Do not edit `dynamic-plugins.default.yaml`** - This file is synced from upstream
- **Do not hardcode cluster URLs** - Use environment variables

## Documentation

### Plugin Documentation Template

Each plugin should have documentation in `docs/<plugin-name>.md` covering:

1. **Description** - What the plugin does
2. **Manual Setup** - Step-by-step manual configuration
3. **Automatic Setup** - How to use the scripts
4. **Demo** - Verification steps
5. **Related Files** - Links to scripts and resources

See existing docs in the `docs/` folder for examples.

### README Updates

If your contribution adds significant new functionality, update the README:

- Add to the features list if applicable
- Update the plugin configuration section if adding new plugins
- Add any new prerequisites

## Questions?

If you have questions or need help:

1. Check existing documentation in `docs/`
2. Review similar plugins for patterns to follow
3. Open an issue for discussion before starting large changes

Thank you for contributing!
