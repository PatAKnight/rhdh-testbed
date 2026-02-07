## Summary

Brief description of changes in this PR.

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] New plugin support (adds integration for a new RHDH plugin)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] CI/CD changes

## Related Issues

Closes #(issue number)

## Changes Made

- Change 1
- Change 2
- Change 3

## Checklist

### General

- [ ] I have read the [CONTRIBUTING](../CONTRIBUTING.md) guide
- [ ] My code follows the project's code conventions
- [ ] I have tested my changes against a real cluster

### Security

- [ ] **No secrets, tokens, or credentials are included in this PR**
- [ ] Secret templates contain only placeholders (empty strings or `<PLACEHOLDER>`)
- [ ] No hardcoded cluster URLs or API endpoints

### For Plugin Contributions

- [ ] Documentation added in `docs/<plugin-name>.md`
- [ ] Configuration script added in `scripts/config-<plugin-name>-plugin.sh`
- [ ] `config-plugins.sh` updated with new mappings
- [ ] Secret templates updated with new placeholders
- [ ] Resource manifests added (if required)
- [ ] All new scripts are executable (`chmod +x`)

## Testing Notes

Describe how you tested these changes:

1.
2.
3.

## Screenshots (if applicable)

Add screenshots to help explain your changes.
