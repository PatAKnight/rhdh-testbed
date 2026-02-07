# Plugin: `backstage-community-plugin-catalog-backend-module-keycloak`

## Description

The `catalog-backend-module-keycloak` plugin enables integration between Backstage and a Keycloak identity provider. It ingests users and group data from a configured Keycloak realm directly into the Backstage catalog, allowing centralized identity management to power you software catalog's ownership model.

---

## How to Configure

You can configure this plugin either manually or automatically using the provided scripts.

### Manual Setup

Manual setup required the following steps:

1. Set up a Keycloak instance (or use an existing one).
2. Create and configure a realm with:
   - A client (with client credentials)
   - Users
   - Groups
3. Configure secrets in RHDH:
   - Update the `rhdh-secrets` secret to include:
     - `KEYCLOAK_BASE_URL`
     - `KEYCLOAK_REALM`
     - `KEYCLOAK_CLIENT_ID`
     - `KEYCLOAK_CLIENT_SECRET`
4. Update the `app-config.yaml`:

   ```YAML
   catalog:
     providers:
       keycloakOrg:
         default:
           baseUrl: ${KEYCLOAK_BASE_URL}
           realm: ${KEYCLOAK_REALM}
           clientId: ${KEYCLOAK_CLIENT_ID}
           clientSecret: ${KEYCLOAK_CLIENT_SECRET}
   ```

---

### Automatic Setup

You can use automation scripts to simplify setup. Two options are available depending on how much you want to deploy.

#### Everything

Requires the `backstage-community-plugin-catalog-backend-module-keycloak-dynamic` to be enabled by setting `disabled: false`.

Runs via:

```bash
./start.sh
```

This will:

- Deploy the RHSSO Operator
- Deploy a Keycloak instance
- Configure:
  - Keycloak realm
  - Keycloak client
  - Users and group hierarchy
- Create the required secrets in the determined namespace

#### Just the Integration

Runs via:

```bash
./scripts/config-keycloak-plugin.sh
```

This script performs the minimal steps required for integration:

- Installs RHSSO Operator
- Deploys a Keycloak instance
- Create the realm, client, users, and groups
- Does not modify or deploy the RHDH instance

Useful when you already have an RHDH deployment and want to plug in Keycloak support only.

## Demo

To verify the integration:

1. Navigate to your RHDH instance's Catalog page.
2. Confirm that the following users appear:
   - `Steve Rogers`
   - `Scott Lang`

This confirms that the catalog is successfully ingesting users from Keycloak

## Related Files

- Resources: `resources/keycloak/` - RHSSO/Keycloak CRS and supporting manifests, `resources/operators/` - RHSSO operator subscription
- Scripts: `scripts/config-keycloak-plugin.sh` - Automates plugin setup
- Auth: `auth/cluster-secrets/` - Related secrets retrieved from the cluster
