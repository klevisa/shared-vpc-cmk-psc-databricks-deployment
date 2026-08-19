# 3. Data Access

> ← Back to the [PoC playbook](../README.md)

**Purpose:** give the workspace governed access to data — a **read-only** catalog over the
client's existing bucket and a **read-write** `analytics` catalog on a new bucket — each
guarded by its own **VPC Service Controls ingress rule** on the perimeter.
**Owner:** Data Platform, with Cloud/Network Security (perimeter ingress) and the bucket
owners (read-only IAM).
**Produces:** the `customer_data_ro` and `analytics` catalogs, plus their ingress rules.

Two Unity Catalog catalogs over GCS: read the client's existing data without touching it, and
write results to a managed `analytics` catalog on a bucket created here.

> **Perimeter changes are split across Phases 3 and 4 on purpose.** This phase adds the
> ingress rules for **data access**; Phase 4 adds the ones for **serverless**. They could be
> combined into a single perimeter change for efficiency, but they're kept separate so the
> client can reason about "data access" and "serverless" independently.

## What it does

**Automation privileges (scoped, least-privilege):**
- the account admin grants the **catalog automation SA** exactly `CREATE_CATALOG` / `CREATE_EXTERNAL_LOCATION` / `CREATE_STORAGE_CREDENTIAL` on the metastore — **not** metastore admin

**Read-only catalog** — over the customer's **existing data bucket**
- storage credential (generates a Databricks SA) → read-only bucket IAM (`objectViewer` + `legacyBucketReader`) → VPC-SC ingress (read methods) → **read-only** external location → catalog + schema (**namespace only** — external tables registered here later)

**Read-write (managed) catalog** — over the **analytics data bucket (created here)**
- create the analytics data bucket → storage credential (its own SA) → read-write bucket IAM (`objectAdmin`) → VPC-SC ingress (all methods) → read-write external location → catalog with a **managed `storage_root`** on the analytics bucket → schema (managed tables land in the bucket)

The automation SA **owns** the catalogs it creates. The metastore *admin* is separate — an IdP-synced human group set as the metastore owner (a prereq), not touched here.

## Pre-reqs

- **Workspace setup complete** (`workspace-setup/`); you have the workspace URL and the region's `metastore_id`.
- **Metastore admin is set up** (prereq, see [`../databricks-account-setup/README.md`](../databricks-account-setup/README.md)): the metastore's **owner** is an IdP-synced human governance group.
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
| `analytics_bucket_sa` | create analytics bucket + read-write IAM | Data Platform | `storage.admin` in the analytics bucket's project |

(Point two identities at the same SA if one team owns both.)

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase:**

- `workspace_url` : from **step 2.4** (`workspace`) output `workspace_url`
- `metastore_id` : the region's metastore (same as the step 2.4 input / prereqs)
- `databricks_account_id` : your Databricks account id

**✍️ Your decisions this phase:**

- `account_admin_sa` / `catalog_automation_sa` : the account admin, and the (manually created) automation SA
- `perimeter_sa` / `data_bucket_sa` / `analytics_bucket_sa` : the three GCP team SAs
- `analytics_bucket` / `analytics_bucket_project` / `analytics_bucket_location` : the analytics data bucket to create
- catalog / schema / storage-credential / external-location names (read-only + read-write)

**📋 Given / lookups** — facts you look up, not free choices:

- `readonly_bucket` / `readonly_bucket_project` : the customer's **existing** data bucket + its project
- `perimeter_name` : the customer's VPC-SC perimeter — `accessPolicies/<policy>/servicePerimeters/<name>`
- `protected_resources` : the perimeter-protected project(s) the buckets live in
- `databricks_source_projects` : **required** — Databricks control-plane + serverless-compute **project numbers** that source-pin the ingress (covers both the storage-credential SA and serverless compute); look them up in the [ip-domain-region table](https://docs.databricks.com/gcp/en/resources/ip-domain-region).

## Outputs

- `analytics_data_bucket` : the analytics data bucket created
- `readonly_catalog` / `readwrite_catalog` : the catalog names
- `readonly_storage_credential_sa` / `readwrite_storage_credential_sa` : the generated Databricks SA emails

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

## Additional info

Two identities, two very different scopes. The **metastore admin** is a *role* — the metastore's **owner** — and belongs to an **IdP-synced human governance group** set when the metastore is created (a prereq); it's future-proof (the owner gets whatever admin capabilities UC adds) and it's not managed here. The **automation SA** is deliberately *not* an admin: the account admin grants it exactly the three `CREATE_*` privileges it needs, and it **owns** the catalogs it creates. A bounded, explicit grant is correct for automation — you don't want it silently gaining new powers.

The automation SA itself is created **manually by the account admin** as part of standing up this phase (a GCP service account registered as a Databricks user) — `data-access` consumes it, it doesn't create it.

Each catalog resolves the same **dependency ordering** in one apply: create the storage credential (which generates the Databricks-managed GCP service account), grant that SA the bucket IAM and add the VPC-SC ingress **using the generated email**, then create the external location — whose creation validates that Databricks can reach the bucket, so IAM + ingress must already be in place (`depends_on` enforces this).

The **read-only** catalog is a pure namespace (no `storage_root`); external tables get registered under it later, pointing into the read-only external location, with viewer-only IAM making writes impossible. The **read-write** catalog gets a `storage_root` on the analytics data bucket, so managed tables land there and `DROP` cleans them up. Read-only is enforced three ways: viewer-only IAM, the external-location `read_only` flag, and read-scoped VPC-SC ingress.

**Source-pinning the ingress (both catalogs).** The VPC-SC ingress admits the generated storage-credential SA **only** when the call originates from Databricks' own projects — set `databricks_source_projects` to Databricks' **control-plane and serverless-compute** project numbers for your region. Including both covers both paths: the storage-credential SA (classic / Unity Catalog operations) and **serverless** compute, which runs in Databricks-owned projects rather than your VPC. Look them up in the [ip-domain-region table](https://docs.databricks.com/gcp/en/resources/ip-domain-region). These are **stable** values Databricks publishes specifically so perimeters can pin to them: an existing project number is never changed out from under a pinned perimeter — that would break every customer who pinned it — so the only change you'd ever see is a **new** number being *added* and announced, which you then reconcile into the list (otherwise traffic from that new project is denied). This is distinct from **firewall** allowlisting, which uses IP ranges (those *do* rotate — see the TODO in `network/network.tf`).

Two caveats: (1) the scoped `CREATE_*` grant must propagate before the automation SA can create catalogs — `depends_on` orders it, but a fresh grant may occasionally need a second apply. (2) The VPC-SC `method_selectors` (`google.storage.objects.get`/`list`) follow the supported-methods reference; if a legitimate read is blocked, widen to `"*"` (write protection still holds via IAM + the read-only external location).
