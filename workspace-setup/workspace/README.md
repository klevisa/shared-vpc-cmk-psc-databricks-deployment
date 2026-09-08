# 2.4 & 2.8 · Create + finalize the workspace — Data / Databricks Platform

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

Creates the workspace through the Databricks **account API**, using the **least-privilege
two-phase** flow. This one config is applied **twice**, toggled by `var.finalize`:

- **PHASE 1 — step 2.4 (`finalize=false`):**
  - **CMEK registration** — registers the step 2.3 key for `STORAGE` + `MANAGED_SERVICES`
  - **PSC endpoint registrations** — registers the two step 2.2 endpoints (flips them **PENDING → ACCEPTED**)
  - **Private access settings** — `public_access_enabled` (immutable after creation)
  - **Network config** — points Databricks at the host-project VPC + node subnet + both endpoints
  - **Workspace** — created **paused in `PROVISIONING`**; Databricks mints and returns the
    workspace SA (`gcp_workspace_sa`) **without** provisioning any GCS/GCE resources
- **PHASE 2 — step 2.8 (`finalize=true`):** re-apply after the workspace SA has its operator
  roles (steps 2.5–2.7). `expected_workspace_status` flips to `RUNNING`, the now-authorized
  workspace SA builds its buckets/VMs, and the workspace is assigned to the metastore.

Why two phases: under least privilege the **creator** SA is read-only, so it can't build the
workspace's storage/compute. The **workspace SA** does — but it doesn't exist until PHASE 1
mints it, and can't create anything until steps 2.5–2.7 grant it operator roles. See
[Create a least-privilege workspace on GCP](https://docs.databricks.com/gcp/en/admin/workspace/create-least-privilege-workspace).

## Pre-reqs

- **steps 2.1, 2.2, and 2.3 have run** — service project + the **read-only creator roles**
  (2.1 service / 2.2 host) granted to this config's SA, the network + PSC endpoints + VPC/subnet
  names (2.2), and the CMEK key id (2.3).
- The impersonated SA is a **Databricks account admin** (one-time, out-of-band setup).
- Databricks Terraform provider **≥ 1.95.0** (for `expected_workspace_status`).
- **PHASE 2 only:** steps 2.5, 2.6, and 2.7 have granted the workspace SA its operator roles.

## Privileges needed

- The impersonated SA (`databricks_account_admin_sa`) is registered as a **Databricks
  account-admin user**, **and** must hold the **read-only workspace-creator roles** on the
  service project (granted in step 2.1) and the host project (step 2.2) — the least-privilege
  flow requires the creator to read/validate settings during creation. It needs **no
  create-capable GCP roles**; the workspace SA does the resource creation (steps 2.5–2.7).

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

- `finalize` : `false` for step 2.4 (create paused), `true` for step 2.8 (finalize → RUNNING)
- `databricks_workspace_name` : name for the workspace
- `public_access_enabled` : `false` = fully private (PSC-only) — **immutable after creation**
- `databricks_account_admin_sa` : the account-admin automation SA this config impersonates (also the creator SA granted read roles in 2.1/2.2)
- `google_region` : the region — must be the same across every phase

**📋 Given / org values** — facts you look up, not free choices:

- `databricks_account_id` : your Databricks account id
- `metastore_id` : the region's Unity Catalog metastore id — **required**; assigned to the workspace in PHASE 2

## Outputs

Available after PHASE 1; `workspace_url` populates once RUNNING (PHASE 2):

- `workspace_id` : the workspace id → **step 2.5 (workspace-sa-roles)** (resource-role IAM condition)
- `gcp_workspace_sa` : the workspace SA (`db-…@prod-gcp-…`) → **steps 2.5, 2.6, 2.7** (operator-role grants)
- `workspace_url` : the workspace URL → **step 2.6 (post-workspace)** (DNS records)
- `metastore_assignment` : set only after PHASE 2 (informational)

## How to run

```bash
# PHASE 1 (step 2.4) — create paused:
terraform init && terraform apply -var-file=terraform.tfvars   # finalize=false
terraform output   # hand gcp_workspace_sa + workspace_id to steps 2.5/2.6/2.7

# ...apply steps 2.5, 2.6, 2.7...

# PHASE 2 (step 2.8) — finalize the SAME state:
terraform apply -var-file=terraform.tfvars -var finalize=true
terraform output   # workspace_url now populated
```

After PHASE 1, **re-check step 2.2's PSC status outputs** — registering the endpoints flips them to **ACCEPTED**.

## Additional info

The workspace comes into being over the Databricks **account API** — there are no `google_*`
resources in this config, so it never reaches the private workspace endpoint (which is what keeps
it working even when `public_access_enabled = false`). The GCP-side resource creation is done by
the **workspace service account** Databricks mints, not by this config's SA.

The order inside PHASE 1 matters: register the **CMEK key** (storage + managed services), register
the two **PSC endpoints** (host project + step 2.2 names), set the **private access settings**,
build the **network config**, then create the **workspace** with `cloud_resource_container` in the
service project and `expected_workspace_status = "PROVISIONING"`. Registering the endpoints is what
makes the *producer* (Databricks) accept the PSC connections, so the step-2.2 forwarding rules flip
**PENDING → ACCEPTED** after this apply.

No **workspace admin** is provisioned here — the account admin running the apply already holds
workspace-admin implicitly. To grant a *delegated* admin, sync them via SCIM first, then assign them
as workspace `ADMIN` over the account API (worked example in `databricks.tf`). Between PHASE 1 and
PHASE 2, three grants must land — they depend only on PHASE 1's outputs and run in parallel:
**step 2.5** (Cloud IAM) grants the workspace SA the project + resource operator roles on the
service project (the create-capable ones); **step 2.6** (Network) grants the network role on the
subnet and writes the DNS records; **step 2.7** (Security/KMS) grants `encrypterDecrypter` on the
CMEK key. Once all three exist, PHASE 2 (`finalize=true`) brings the workspace to `RUNNING`.
