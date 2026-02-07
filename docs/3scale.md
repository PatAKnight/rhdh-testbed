# Plugin: @backstage-community/plugin-3scale-backend

## Description

The 3scale plugin integrates 3scale API Management with Backstage, allowing you to ingest and manage API documentation from 3scale directly into the Backstage catalog. This can be especially useful in developer portals that need to showcase APIs registered in 3scale, along with metadata like ownership, paths, and documentation.

---

## How to Configure

You can configure this plugin either manually or automatically using the provided scripts.

### Manual Setup

1. Deploy required infrastructure:
   - Install the 3scale Operator.
   - Deploy a Minio instance (or use another S3-compatible object storage if preferred).
   - Deploy an `APIManager` custom resource.
   - Create and configure `ActiveDoc` custom resources that define the APIs to be exposed.
2. Ingest into RHDH:
   - Ensure that you have enabled the 3scale backend plugin.
   - Update your `app-config.yaml` to include the 3scale provider configuration under `catalog.providers.threeScaleApiEntity`.

     ```YAML
     catalog:
       providers:
         threeScaleApiEntity:
           default:
             baseUrl: ${THREESCALE_BASE_URL}
             accessToken: ${THREESCALE_ACCESS_TOKEN}
     ```

   - Backstage should then auto-ingest APIs exposed via 3scale `ActiveDoc` into the catalog

---

### Automatic Setup

Automated setup is available in two levels depending on how much you want configured for you.

#### Everything

Runs the root-level script to:

- Deploy Minio.
- Install the 3scale Operator.
- Deploy an `APIManager` custom resource.
- Deploy `ActiveDoc` API definitions.
- Set required secrets.
- Ingest APIs into the RHDH catalog automatically

**Run:**

```bash
./start.sh
```

#### Just the Integration

Only configures the integration resources for this plugin. Use this if you already have a Backstage instance running and just need this plugin.

**Run:**

```bash
./scripts/config-3scale-plugin.sh
```

This script will just install the minimal required for integrating with an RHDH instance.

- Deploy Minio.
- Install the 3scale Operator.
- Deploy an `APIManager` custom resource.
- Deploy `ActiveDoc` API definitions.

## Demo

1. Go to your RHDH instance.
2. Open the Catalog.
3. Change the filter to APIs.
4. Look for the API `pet-store` or others ingested from 3scale.
5. Click the API entity to view detailed information.

## Related Files

- `scripts/config-3scale-plugin.sh` - Automates plugin setup
- `/resources/3scale/` - 3scale CRs and supporting manifests
- `/resources/operators/` - 3scale operator subscription

## Notes

- A lot of inspiration for setting up the 3scale infrastructure came from this source: <https://github.com/maarten-vandeperre/developer-hub-documentation>.
