# Catalog setup — read-only + read-write UC catalogs over GCS

The step **after** workspace setup: register two Unity Catalog catalogs over GCS buckets,
with VPC-SC ingress. Built for a PoC — read the customer's existing data without touching it,
and write results to a separate scratch bucket.

## What it does

Two catalogs, same mechanism, opposite access:

- **Read-only catalog** — over the customer's **existing data bucket**
  - storage credential (generates a Databricks SA) → bucket IAM `objectViewer` + `legacyBucketReader` → VPC-SC ingress (read methods) → **read-only** external location → catalog + schema
  - **namespace only, no managed storage** — external tables get registered here later
- **Read-write catalog** — over a separate **scratch / output bucket**
  - storage credential (its own SA) → bucket IAM `objectAdmin` + `legacyBucketReader` → VPC-SC ingress (all methods) → read-write external location → catalog with a **managed `storage_root`** + schema
  - managed tables (`saveAsTable` / `CREATE TABLE …`) land in the scratch bucket

Read-only is enforced three ways: viewer-only IAM, the external-location `read_only` flag, and read-scoped VPC-SC ingress.

## Pre-reqs

- **Workspace setup is complete** (`workspace-setup-multi-team/`, Phases 0-4) and you have the workspace URL.
- **Both buckets already exist** — the customer's data bucket and a scratch bucket. This config wires to them; it does not create them.
- A **VPC-SC perimeter** exists (customer-supplied) and you can attach ingress policies to it.

> Unity Catalog objects are created against the **workspace API**. If the workspace is private (`public_access_enabled = false`), run this from somewhere that can reach the workspace endpoint (inside or peered to the VPC).

## Privileges needed

- **Data Platform SA** (`databricks_service_account_email`): Unity Catalog metastore-admin / CREATE on the metastore (creates the credentials, external locations, catalogs, schemas).
- **Security SA** (`gcp_service_account_email`): bucket IAM admin on the buckets' project(s) + `roles/accesscontextmanager.policyAdmin` on the perimeter (bucket grants + VPC-SC ingress).

Each runner needs `roles/iam.serviceAccountTokenCreator` on the SA it impersonates.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output:

- `workspace_url` : the workspace to create UC objects against — from **Phase 3** (`databricks-account`) output `workspace_url`

**✍️ Your decisions this phase:**

- `databricks_service_account_email` / `gcp_service_account_email` : the two SAs this config impersonates
- `google_project` : quota/context project for the google provider
- `readonly_catalog_name` / `readonly_schema_name` : names for the read-only catalog + schema
- `readonly_storage_credential_name` / `readonly_external_location_name` : names for its credential + external location
- `readwrite_catalog_name` / `readwrite_schema_name` : names for the read-write catalog + schema
- `readwrite_storage_credential_name` / `readwrite_external_location_name` : names for its credential + external location

**📋 Given / lookups** — facts you look up, not free choices:

- `readonly_bucket` : the customer's **existing** data bucket (name only)
- `readwrite_bucket` : the **existing** scratch/output bucket (name only)
- `perimeter_name` : the customer's VPC-SC perimeter — `accessPolicies/<policy>/servicePerimeters/<name>`
- `protected_resources` : the perimeter-protected project(s) the buckets live in (e.g. `["projects/222222222222"]`, or `["*"]`)

## Outputs

- `readonly_catalog` / `readwrite_catalog` : the created catalog names
- `readonly_storage_credential_sa` / `readwrite_storage_credential_sa` : the generated Databricks SA emails (granted on the buckets and named in the VPC-SC ingress)

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

## Additional info

This runs once the workspace exists and is attached to the region's metastore — Unity Catalog objects (storage credentials, external locations, catalogs) are metastore-scoped and created through the workspace.

Each catalog resolves the same **bootstrap ordering** in one apply: create the storage credential (which generates the Databricks-managed GCP service account), grant that SA the bucket IAM and add the VPC-SC ingress rule **using the generated email**, and only then create the external location — whose creation validates that Databricks can actually reach the bucket, so the IAM + ingress must already be in place (`depends_on` enforces this).

The **read-only** catalog is a pure namespace — no `storage_root`, because managed storage means writable. External tables get registered under it later, pointing into the read-only external location; UC governs access and the viewer-only IAM makes writes impossible. The **read-write** catalog gets a `storage_root` on the scratch bucket, so managed tables written to it land there and `DROP` cleans them up — a frictionless "write here" target for the PoC. (A `storage_root` catalog still allows external tables at explicit paths too, if needed.)

The VPC-SC ingress uses `method_selectors` to scope the read-only credential to `google.storage.objects.get` / `list`. Those method names follow the VPC-SC supported-methods reference — if a legitimate read is blocked, widen to `"*"` (write protection still holds via the viewer-only IAM and the read-only external location).
