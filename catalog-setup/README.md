# Catalog setup — read-only + read-write UC catalogs over GCS

The step **after** workspace setup: designate a metastore admin, then register two Unity
Catalog catalogs over GCS with VPC-SC ingress. Built for a PoC — read the customer's
existing data without touching it, and write results to a PoC data bucket created here.

## What it does

**Metastore admin (from the account admin):**
- creates a **regional metastore-admin group**, adds the **specified SA** to it, and grants the group metastore `CREATE CATALOG` / `CREATE EXTERNAL LOCATION` / `CREATE STORAGE CREDENTIAL`
- that SA (now a metastore admin) creates everything below

**Read-only catalog** — over the customer's **existing data bucket**
- storage credential (generates a Databricks SA) → read-only bucket IAM (`objectViewer` + `legacyBucketReader`) → VPC-SC ingress (read methods) → **read-only** external location → catalog + schema (**namespace only** — external tables registered here later)

**Read-write catalog** — over the **PoC data bucket (created here)**
- create the PoC data bucket → storage credential (its own SA) → read-write bucket IAM (`objectAdmin`) → VPC-SC ingress (all methods) → read-write external location → catalog with a **managed `storage_root`** on the PoC bucket → schema (managed tables land in the bucket)

## Pre-reqs

- **Workspace setup complete** (`workspace-setup-multi-team/`) and you have the workspace URL + the region's `metastore_id`.
- The **metastore-admin SA is registered as a Databricks user** (its GSA email) so it can be added to the group and authenticate.
- The customer's **data bucket exists**; a **VPC-SC perimeter exists** (customer-supplied) you can attach ingress to.

> Unity Catalog objects are created against the **workspace API**. For a private (`public_access_enabled = false`) workspace, run this from somewhere that can reach the workspace endpoint (inside or peered to the VPC).

## Privileges needed

Each identity is impersonated by its own aliased provider; each runner needs `roles/iam.serviceAccountTokenCreator` on it:

| Identity | Does | Team | Role |
|---|---|---|---|
| `account_admin_sa` | group + member + metastore grant | (from prereqs) | Databricks **account admin** |
| `metastore_admin_sa` | creates credentials / locations / catalogs | Data Platform | member of the metastore-admin group |
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

- `account_admin_sa` / `metastore_admin_sa` : the account admin, and the SA to make a metastore admin
- `metastore_admin_group_name` : the regional metastore-admin group to create
- `perimeter_sa` / `data_bucket_sa` / `poc_bucket_sa` : the three GCP team SAs
- `poc_bucket` / `poc_bucket_project` / `poc_bucket_location` : the PoC data bucket to create
- catalog / schema / storage-credential / external-location names (read-only + read-write)

**📋 Given / lookups** — facts you look up, not free choices:

- `readonly_bucket` / `readonly_bucket_project` : the customer's **existing** data bucket + its project
- `perimeter_name` : the customer's VPC-SC perimeter — `accessPolicies/<policy>/servicePerimeters/<name>`
- `protected_resources` : the perimeter-protected project(s) the buckets live in

## Outputs

- `metastore_admin_group` : the group created (the SA is a member)
- `poc_data_bucket` : the PoC data bucket created
- `readonly_catalog` / `readwrite_catalog` : the catalog names
- `readonly_storage_credential_sa` / `readwrite_storage_credential_sa` : the generated Databricks SA emails

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

## Additional info

The chain is **account admin → metastore admin → catalogs**. The account admin doesn't create the catalogs directly; it stands up a **regional metastore-admin group**, drops the specified SA into it, and grants the group metastore CREATE privileges. That SA — now a metastore admin — creates the storage credentials, external locations, and catalogs. Any future automation identity just joins the group.

Each catalog resolves the same **bootstrap ordering** in one apply: create the storage credential (which generates the Databricks-managed GCP service account), grant that SA the bucket IAM and add the VPC-SC ingress rule **using the generated email**, then create the external location — whose creation validates that Databricks can reach the bucket, so IAM + ingress must already be in place (`depends_on` enforces this).

The **read-only** catalog is a pure namespace (no `storage_root`); external tables get registered under it later, pointing into the read-only external location, with viewer-only IAM making writes impossible. The **read-write** catalog gets a `storage_root` on the PoC data bucket, so managed tables written to it land there and `DROP` cleans them up. Read-only is enforced three ways: viewer-only IAM, the external-location `read_only` flag, and read-scoped VPC-SC ingress.

Two caveats: (1) the metastore CREATE grant must propagate before the metastore-admin SA can create catalogs — `depends_on` orders it, but on a fresh grant you may occasionally need a second apply. (2) The VPC-SC `method_selectors` (`google.storage.objects.get`/`list`) follow the supported-methods reference; if a legitimate read is blocked, widen to `"*"` (write protection still holds via IAM + the read-only external location).
