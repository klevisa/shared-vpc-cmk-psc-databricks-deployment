# 2.4 · Create the workspace — Data / Databricks Platform

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

Creates the workspace — entirely through the Databricks **account API**, no GCP resources:

- **CMEK registration** — registers the step 2.3 key for `STORAGE` + `MANAGED_SERVICES`
- **PSC endpoint registrations** — registers the two step 2.2 endpoints (this is what flips them **PENDING → ACCEPTED**)
- **Private access settings** — sets `public_access_enabled` (immutable after creation)
- **Network config** — points Databricks at the host-project VPC + node subnet + both endpoints
- **Workspace** — created with its GCE/GCS resources in the **service** project, wired to the network, PAS, and CMEK

No workspace admin is created — the account admin running this already has it (see Additional info).

## Pre-reqs

- **steps 2.1, 2.2, and 2.3 have run** — you have the service project (step 2.1), the network + PSC endpoints + VPC/subnet names (step 2.2), and the CMEK key id (step 2.3).
- The impersonated SA is a **Databricks account admin** (a one-time setup done by a human account admin — nothing can grant the first account admin, so it's out of band).

## Privileges needed

- The impersonated SA (`google_service_account_email`) is registered as a **Databricks account-admin user**. This phase talks only to `accounts.gcp.databricks.com`, so it needs **no GCP project roles**.

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `google_project_name` : the **service** project id — from **step 2.1** `service_project_id`
- `cmek_key_id` : the CMEK key resource id — from **step 2.3** `cmek_key_id`
- `vpc_network_project_id` : the host project id — from **step 2.2** `host_project`
- `vpc_name` : the VPC — from **step 2.2** `vpc_name`
- `node_subnet_name` : the node subnet — from **step 2.2** `node_subnet_name`
- `workspace_pe` / `relay_pe` : the frontend / backend PSC endpoint names — from **step 2.2**

**✍️ Your decisions this phase:**

- `databricks_workspace_name` : name for the workspace
- `public_access_enabled` : `false` = fully private (PSC-only) — **immutable after creation**
- `google_service_account_email` : the Data Platform SA this config impersonates
- `google_region` : the region — a decision, but it **must be the same** across every phase

**📋 Given / org values** — facts you look up, not free choices:

- `databricks_account_id` : your Databricks account id (from the account console)
- `metastore_id` : the region's Unity Catalog metastore id — **required**; the workspace is explicitly assigned to it (see [`../../databricks-account-setup/README.md`](../../databricks-account-setup/README.md))

## Outputs

Copied into the next phase's `terraform.tfvars` (or wired via `terraform_remote_state`):

- `workspace_id` : the workspace id → **step 2.5 (post-workspace)**
- `workspace_url` : the workspace URL → **step 2.5 (post-workspace)** (DNS records)
- `gcp_workspace_sa` : the workspace service account (`db-…@prod-gcp-…`) → **step 2.5 (post-workspace)** (subnet grant)
- `metastore_assignment` : the metastore assigned to the workspace (informational)

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

Then **re-check step 2.2's PSC status outputs** — registering the endpoints here flips them to **ACCEPTED**. Hand the outputs above to step 2.5.

## Additional info

This is where the workspace actually comes into being, and it happens entirely over the Databricks **account API** — there are no `google_*` resources in this phase, so it never has to reach the private workspace endpoint (which is what keeps it working even when `public_access_enabled = false`).

The order inside the phase matters: we **register the CMEK key** (step 2.3's key id, for both storage and managed services), **register the two PSC endpoints** (referencing the host project and the step 2.2 endpoint names), set the **private access settings**, build the **network config** pointing at the host-project VPC and node subnet, and finally create the **workspace** with `cloud_resource_container` in the service project. Registering the endpoints is also what makes the *producer* (Databricks) accept the PSC connections — so after this apply, the forwarding rules step 2.2 created flip from **PENDING** to **ACCEPTED**.

No **workspace admin** is provisioned here. The account admin running this apply already holds workspace-admin implicitly on every workspace it creates, so the workspace is administered the moment it exists. To grant a *delegated* admin (a human who shouldn't be a full account admin), sync them via SCIM into the account first, then assign them as workspace `ADMIN` over the account API (worked example in `databricks.tf`). The workspace is not fully usable yet: clusters can't launch and hostnames don't resolve until **step 2.5** grants the workspace SA on the subnet and writes the DNS records.
