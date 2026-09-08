# 2.5 · Workspace SA operator roles — Cloud IAM

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

Grants the Databricks **workspace service account** (minted by step 2.4) the two operator
roles on the **service** project that authorize it to build the workspace's own resources:

- **Project role** (`lpw.databricks.project.role.v2`) — project-wide read + `iam.serviceAccounts.actAs`
- **Resource role** (`lpw.databricks.resource.role.v2`) — `storage.buckets.create`, `compute.instances.create`, disk/object management — **scoped by an IAM condition to this workspace's resources**

This is the step that lets the workspace actually create its GCS buckets and cluster VMs. In
a least-privilege deployment the workspace creator SA is read-only, so **nothing** can provision
the workspace's storage/compute until these roles land — which is why the workspace is created
paused in step 2.4 and only finalized in step 2.8, after this step and steps 2.6–2.7.

The **network role** (subnet) is granted by the network team in step 2.6; the **CMEK** grant by
security in step 2.7.

## Pre-reqs

- **step 2.4 (PHASE 1) has run** — the workspace is in `PROVISIONING` and you have its
  `gcp_workspace_sa` and `workspace_id` outputs.

## Privileges needed

On the impersonated Cloud IAM SA (`google_service_account_email`), against the **service** project:

- `roles/iam.roleAdmin` — create the two custom roles
- `roles/resourcemanager.projectIamAdmin` — grant them to the workspace SA

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `google_project_name` : the **service** project id — from **step 2.1** `service_project_id`
- `gcp_workspace_sa` : the workspace service account — from **step 2.4** `gcp_workspace_sa`
- `workspace_id` : the workspace id — from **step 2.4** `workspace_id` (used in the resource-role IAM condition)

**✍️ Your decisions this phase:**

- `google_service_account_email` : the Cloud IAM SA this config impersonates
- `google_region` : the region — must match every phase

## Outputs

- `project_role_id` / `resource_role_id` : the created custom roles (informational)

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars
```

Runs in parallel with steps 2.6 and 2.7 (all three depend only on step 2.4's outputs). Once all
three are applied, run step 2.8 (`workspace/` with `finalize=true`) to bring the workspace RUNNING.

## Additional info

The permission lists and the resource-role IAM condition are transcribed from
[Required permissions for the workspace service account](https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/sa-permissions)
— treat that page as the source of truth and re-verify in review. The condition
(`resource.name.extract("{x}databricks") != "" && resource.name.extract("{x}<workspace-id>") != ""`)
limits the create/delete/use permissions to resources whose names carry both `databricks` and this
workspace's id (its `databricks-<workspace-id>` buckets and workspace-tagged instances/disks), so
the grant can't be used against unrelated resources in the project.
