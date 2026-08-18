# Catalog setup — read-only + read-write UC catalogs over GCS

The step **after** workspace setup: register two Unity Catalog catalogs over GCS with
VPC-SC ingress. Built for a PoC — read the customer's existing data without touching it,
and write results to a PoC data bucket created here.

## What it does

**Automation privileges (scoped, least-privilege):**
- the account admin grants the **catalog automation SA** exactly `CREATE_CATALOG` / `CREATE_EXTERNAL_LOCATION` / `CREATE_STORAGE_CREDENTIAL` on the metastore — **not** metastore admin

**Read-only catalog** — over the customer's **existing data bucket**
- storage credential (generates a Databricks SA) → read-only bucket IAM (`objectViewer` + `legacyBucketReader`) → VPC-SC ingress (read methods) → **read-only** external location → catalog + schema (**namespace only** — external tables registered here later)

**Read-write catalog** — over the **PoC data bucket (created here)**
- create the PoC data bucket → storage credential (its own SA) → read-write bucket IAM (`objectAdmin`) → VPC-SC ingress (all methods) → read-write external location → catalog with a **managed `storage_root`** on the PoC bucket → schema (managed tables land in the bucket)

The automation SA **owns** the catalogs it creates. The metastore *admin* is separate — an IdP-synced human group set as the metastore owner (a prereq), not touched here.

## Pre-reqs

- **Workspace setup complete** (`workspace-setup-multi-team/`); you have the workspace URL and the region's `metastore_id`.
- **Metastore admin is set up** (prereq, see [`../docs/databricks-prerequisites.md`](../docs/databricks-prerequisites.md)): the metastore's **owner** is an IdP-synced human governance group.
- **The catalog automation SA exists**: the account admin has **manually created** it and registered it as a Databricks user (its GSA email) so it can authenticate. This is a one-time manual step done as part of setting up this phase.
- The customer's **data bucket exists**; a **VPC-SC perimeter exists** (customer-supplied) you can attach ingress to.

> Unity Catalog objects are created against the **workspace API**. For a private (`public_access_enabled = false`) workspace, run this from somewhere that can reach the workspace endpoint (inside or peered to the VPC).

## Privileges needed

Each identity is impersonated by its own aliased provider; each runner needs `roles/iam.serviceAccountTokenCreator` on it:

| Identity | Does | Team | Rights |
|---|---|---|---|
| `account_admin_sa` | grants the automation SA scoped `CREATE_*` | (from prereqs) | Databricks **account admin** |
| `catalog_automation_sa` | creates + owns credentials / locations / catalogs | Data Platform | only the granted `CREATE_*` |
| `perimeter_sa` | VPC-SC ingress | Cloud / Network Security | `accesscontextmanager.policyAdmin` |
| `data_bucket_sa` | read-only IAM on the existing data bucket | owner of that bucket's project | bucket IAM admin |
| `poc_bucket_sa` | create PoC bucket + read-write IAM | Data Platform | `storage.admin` in the PoC bucket's project |

(Point two identities at the same SA if one team owns both.)

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase:**

- `workspace_url` : from **Phase 3** (`databricks-account`) output `workspace_url`
- `metastore_id` : the region's metastore (same as the Phase 3 input / prereqs)
- `databricks_account_id` : your Databricks account id

**✍️ Your decisions this phase:**

- `account_admin_sa` / `catalog_automation_sa` : the account admin, and the (manually created) automation SA
- `perimeter_sa` / `data_bucket_sa` / `poc_bucket_sa` : the three GCP team SAs
- `poc_bucket` / `poc_bucket_project` / `poc_bucket_location` : the PoC data bucket to create
- catalog / schema / storage-credential / external-location names (read-only + read-write)

**📋 Given / lookups** — facts you look up, not free choices:

- `readonly_bucket` / `readonly_bucket_project` : the customer's **existing** data bucket + its project
- `perimeter_name` : the customer's VPC-SC perimeter — `accessPolicies/<policy>/servicePerimeters/<name>`
- `protected_resources` : the perimeter-protected project(s) the buckets live in
- `databricks_source_projects` : (optional) Databricks control-plane + serverless-compute **project numbers** to source-pin the ingress — look them up in the [ip-domain-region table](https://docs.databricks.com/gcp/en/resources/ip-domain-region). Empty (`[]`) = identity-only.

## Outputs

- `poc_data_bucket` : the PoC data bucket created
- `readonly_catalog` / `readwrite_catalog` : the catalog names
- `readonly_storage_credential_sa` / `readwrite_storage_credential_sa` : the generated Databricks SA emails

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

## Additional info

Two identities, two very different scopes. The **metastore admin** is a *role* — the metastore's **owner** — and belongs to an **IdP-synced human governance group** set when the metastore is created (a prereq); it's future-proof (the owner gets whatever admin capabilities UC adds) and it's not managed here. The **automation SA** is deliberately *not* an admin: the account admin grants it exactly the three `CREATE_*` privileges it needs, and it **owns** the catalogs it creates. A bounded, explicit grant is correct for automation — you don't want it silently gaining new powers.

The automation SA itself is created **manually by the account admin** as part of standing up this phase (a GCP service account registered as a Databricks user) — `catalog-setup` consumes it, it doesn't create it.

Each catalog resolves the same **bootstrap ordering** in one apply: create the storage credential (which generates the Databricks-managed GCP service account), grant that SA the bucket IAM and add the VPC-SC ingress **using the generated email**, then create the external location — whose creation validates that Databricks can reach the bucket, so IAM + ingress must already be in place (`depends_on` enforces this).

The **read-only** catalog is a pure namespace (no `storage_root`); external tables get registered under it later, pointing into the read-only external location, with viewer-only IAM making writes impossible. The **read-write** catalog gets a `storage_root` on the PoC data bucket, so managed tables land there and `DROP` cleans them up. Read-only is enforced three ways: viewer-only IAM, the external-location `read_only` flag, and read-scoped VPC-SC ingress.

**Source-pinning the ingress (optional, both catalogs).** By default the VPC-SC ingress is *identity-only*: it admits the generated storage-credential SA regardless of where the call comes from — which is what lets **serverless** compute (running in Databricks-owned projects, not your VPC) read the buckets. To tighten it, set `databricks_source_projects` to Databricks' **control-plane + serverless-compute project numbers** for your region, so the SA is admitted *only* when the call originates from those projects. These are **stable, per-region** values — look them up once in the [ip-domain-region table](https://docs.databricks.com/gcp/en/resources/ip-domain-region) (there's no API feed for the project numbers, but they rarely change). Note this is distinct from **firewall** allowlisting, which uses IP ranges (those *do* rotate — see the TODO in `host-network/network.tf`).

Two caveats: (1) the scoped `CREATE_*` grant must propagate before the automation SA can create catalogs — `depends_on` orders it, but a fresh grant may occasionally need a second apply. (2) The VPC-SC `method_selectors` (`google.storage.objects.get`/`list`) follow the supported-methods reference; if a legitimate read is blocked, widen to `"*"` (write protection still holds via IAM + the read-only external location).
