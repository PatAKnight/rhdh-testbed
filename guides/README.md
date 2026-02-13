# RHDH Testbed Guides

This directory contains in-depth technical guides for RHDH plugin configurations, troubleshooting,
and advanced setups.

## Purpose

While the `docs/` directory provides **reference documentation** for each plugin (overview, setup,
basic usage), the `guides/` directory offers **how-to guides** and **deep-dive technical content**
for developers and operators.

## Directory Structure

```
guides/
├── README.md                          # This file
├── nexus-troubleshooting.md          # Nexus plugin troubleshooting
├── nexus-advanced-config.md          # Nexus production setup
└── [future guides]
```

## Available Guides

### Nexus Repository Manager

- **[Troubleshooting Guide](nexus-troubleshooting.md)** - Diagnose and fix common issues
  - Operator installation problems
  - Nexus instance startup issues
  - Demo data failures
  - Plugin integration problems
  - Network connectivity
  - Performance issues
- **[Advanced Configuration](nexus-advanced-config.md)** - Production-ready setups
  - Persistent storage configuration
  - Resource tuning and JVM optimization
  - High availability strategies
  - Custom repository creation
  - Security configuration (LDAP, RBAC, SSL/TLS)
  - Backup and restore procedures
  - Monitoring and metrics
  - Performance optimization

## When to Use Docs vs Guides

### Use `docs/<plugin>.md` for:

- Plugin overview and description
- Quick start and basic setup
- Demo instructions
- File references
- Standard usage patterns

### Use `guides/<plugin>-*.md` for:

- Detailed troubleshooting procedures
- Production configuration examples
- Performance tuning
- Security hardening
- Advanced integrations
- Operational procedures
- Deep technical details

## Guide Template

When creating new guides, follow this structure:

```markdown
# [Plugin Name] - [Guide Type]

Brief introduction explaining what this guide covers.

---

## Table of Contents

- [Section 1](#section-1)
- [Section 2](#section-2)

---

## Section 1

### Subsection

**Problem/Scenario:** Description

**Diagnosis:** \`\`\`bash commands to diagnose \`\`\`

**Solution:** \`\`\`bash commands to fix \`\`\`

---

## Additional Resources

- Links to official docs
- Related guides
```

## Contributing Guides

When adding new plugin support, consider creating:

1. **Troubleshooting Guide** if the plugin:
   - Has complex installation steps
   - Commonly encounters issues
   - Requires operator/CRD management
   - Has network/connectivity requirements

2. **Advanced Configuration Guide** if the plugin:
   - Supports production deployments
   - Has performance tuning options
   - Requires security configuration
   - Supports high availability
   - Has complex integration scenarios

Not every plugin needs these guides - simple plugins with straightforward setup can rely solely on
`docs/` documentation.

## Feedback

These guides are living documents. If you encounter issues not covered here or have suggestions for
additional topics, please contribute!
