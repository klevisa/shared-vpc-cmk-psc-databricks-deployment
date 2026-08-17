# Phase 3 — databricks-account (Data / Databricks Platform)

## What it does

Creates the workspace — entirely through the Databricks **account API**, no GCP resources:

- **CMEK registration** — registers the Phase 2 key for `STORAGE` + `MANAGED_SERVICES`
- **PSC endpoint registrations** — registers the two Phase 1 endpoints (this is what flips them **PENDING → ACCEPTED**)
- **Private access settings** — sets `public_access_enabled` (immutable after creation)
- **Network config** — points Databricks at the host-project VPC + node subnet + both endpoints
- **Workspace** — created with its GCE/GCS resources in the **service** project, wired to the network, PAS, and CMEK

No workspace admin is created — the account admin running this already has it (see Additional info).

## Pre-reqs

- **Phases 0, 1, and 2 have run** — you have the service project (Phase 0), the network + PSC endpoints + VPC/subnet names (Phase 1), and the CMEK key id (Phase 2).
- The impersonated SA is a **Databricks account admin** (a one-time setup — see [`../../docs/identity-and-access.md`](../../docs/identity-and-access.md)).

## Privileges needed

- The impersonated SA (`google_service_account_email`) is registered as a **Databricks account-admin user**. This phase talks only to `accounts.gcp.databricks.com`, so it needs **no GCP project roles**.

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `google_project_name` : the **service** project id — from **Phase 0** `service_project_id`
- `cmek_key_id` : the CMEK key resource id — from **Phase 2** `cmek_key_id`
- `vpc_network_project_id` : the host project id — from **Phase 1** `host_project`
- `vpc_name` : the VPC — from **Phase 1** `vpc_name`
- `node_subnet_name` : the node subnet — from **Phase 1** `node_subnet_name`
- `workspace_pe` / `relay_pe` : the frontend / backend PSC endpoint names — from **Phase 1**

**✍️ Your decisions this phase:**

- `databricks_workspace_name` : name for the workspace
- `public_access_enabled` : `false` = fully private (PSC-only) — **immutable after creation**
- `metastore_id` : optional existing UC metastore to assign (empty = auto-assignment)
- `google_service_account_email` : the Data Platform SA this config impersonates
- `google_region` : the region — a decision, but it **must be the same** across every phase

**📋 Given / org values** — facts you look up, not free choices:

- `databricks_account_id` : your Databricks account id (from the account console)

## Outputs

Copied into the next phase's `terraform.tfvars` (or wired via `terraform_remote_state`):

- `workspace_id` : the workspace id → **Phase 4 (post-workspace)**
- `workspace_url` : the workspace URL → **Phase 4 (post-workspace)** (DNS records)
- `gcp_workspace_sa` : the workspace service account (`db-…@prod-gcp-…`) → **Phase 4 (post-workspace)** (subnet grant)
- `metastore_assignment` : which metastore was assigned, or "none" (informational)

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

Then **re-check Phase 1's PSC status outputs** — registering the endpoints here flips them to **ACCEPTED**. Hand the outputs above to Phase 4.

## Additional info

This is where the workspace actually comes into being, and it happens entirely over the Databricks **account API** — there are no `google_*` resources in this phase, so it never has to reach the private workspace endpoint (which is what keeps it working even when `public_access_enabled = false`).

The order inside the phase matters: we **register the CMEK key** (Phase 2's key id, for both storage and managed services), **register the two PSC endpoints** (referencing the host project and the Phase 1 endpoint names), set the **private access settings**, build the **network config** pointing at the host-project VPC and node subnet, and finally create the **workspace** with `cloud_resource_container` in the service project. Registering the endpoints is also what makes the *producer* (Databricks) accept the PSC connections — so after this apply, the forwarding rules Phase 1 created flip from **PENDING** to **ACCEPTED**.

No **workspace admin** is provisioned here. The account admin running this apply already holds workspace-admin implicitly on every workspace it creates, so the workspace is administered the moment it exists. To grant a *delegated* admin (a human who shouldn't be a full account admin), sync them via SCIM and assign them over the account API — see [`../../docs/identity-and-access.md`](../../docs/identity-and-access.md). The workspace is not fully usable yet: clusters can't launch and hostnames don't resolve until **Phase 4** grants the workspace SA on the subnet and writes the DNS records.
