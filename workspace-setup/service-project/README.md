# 2.1 · Create service project — Cloud Foundation

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

Lays the shared base the other phases build on. The **host project already exists** and is only referenced; everything else is created here:

- **Service project** — where the workspace's compute, storage, and CMEK key will live
- **API enablement** — turns on the required Google APIs on the **service project** (the host's are already enabled — it's a long-standing Shared VPC host)
  - Enabling the Compute API also provisions the compute service agent that step 2.3's CMEK grant needs
- **Shared VPC attachment** — **attaches** the service project to the existing Shared VPC host
- **GCS service agent** — provisioned on the service project so step 2.3's CMEK grant doesn't fail with `400 … does not exist`

## Pre-reqs

- The **host project exists** (the network team's existing shared network project).
- An **org or folder** to create the service project under, and a **billing account** to link.

> This is the shared foundation another team normally owns. It runs **once** and rarely changes.

## Privileges needed

On the impersonated foundation SA (`google_service_account_email`), at the **org / folder** level:

- `roles/resourcemanager.projectCreator` — create the service project
- `roles/billing.user` — link the billing account
- `roles/compute.xpnAdmin` — attach the service project to the Shared VPC host
- `roles/resourcemanager.projectIamAdmin` + `roles/serviceusage.serviceUsageAdmin` — set IAM / enable APIs

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — none; this is the first phase.

**✍️ Your decisions this phase:**

- `service_project_id` : globally-unique id for the service project to create
- `service_project_name` : its human-readable display name
- `org_id` **or** `folder_id` : where to create the service project (set exactly one)
- `google_service_account_email` : the foundation SA this config impersonates
- `google_region` : the region — a decision, but it **must be the same** across every phase
- `service_project_apis` : which APIs to enable on the service project (sensible defaults; override only if needed)

**📋 Given / org values** — facts you look up, not free choices:

- `vpc_network_project_id` : the **existing** host project id you're deploying into
- `billing_account` : your org's billing account id (e.g. `XXXXXX-XXXXXX-XXXXXX`)

## Outputs

Copied into later phases' `terraform.tfvars` (or wired via `terraform_remote_state`):

- `host_project` : the host project id → **step 2.2 (network)**
- `service_project_id` : the created service project id → **step 2.3 (cmek)** & **step 2.4 (workspace)**
- `service_project_number` : its numeric project number → **step 2.2 (network)** & **step 2.3 (cmek)** (service-agent emails)
- `gcs_service_agent` : the GCS service agent email → granted CMEK access in **step 2.3** (reference)

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

Then hand the outputs to the next phases.

## Additional info

step 2.1 exists so no later phase needs org-level power. The **host project** is the network team's existing shared network, so this config never creates or modifies it — it only **attaches** the new service project to it. It **creates the service project** (the "tenant" for this one workspace), links billing, and turns on the APIs the service project needs (the host's are already on). GCP services are off by default, so without this step step 2.3 couldn't create a KMS key, step 2.4 couldn't reach the compute service agent, and so on.

It then **establishes the Shared VPC relationship** — enabling the host and attaching the service project — which is the platform capability that later lets a VM *owned by the service project* run on a *subnet owned by the host project* (step 2.2 grants the specific subnet permissions, step 2.5 grants the workspace SA). Finally it **provisions the service agents**: the GCS agent via a data source, and the compute agent implicitly by enabling the Compute API, so step 2.3's CMEK grants have real principals to bind to.
