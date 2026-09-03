# 2.3 · Customer-managed encryption key (CMEK) — Cloud Security / KMS

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

Creates the customer-managed encryption key (CMEK) in the **service project** and grants the project's Google-managed agents permission to use it:

- **Key ring + crypto key** — the CMEK the workspace's storage and managed services are encrypted with
- **Service-agent grants** — `cryptoKeyEncrypterDecrypter` to the service project's:
  - `compute-system` agent (VM disks)
  - `gs-project-accounts` agent (GCS)

Runs **in parallel with step 2.2** (they don't depend on each other).

## Pre-reqs

- **step 2.1 (`service-project/`) has run** — the service project exists, its APIs are enabled, and its GCS/compute service agents exist (or the grants fail with `400 … does not exist`).
- You have step 2.1's outputs `service_project_id` and `service_project_number`.

## Privileges needed

On the impersonated security SA (`google_service_account_email`), against the **service** project:

- `roles/cloudkms.admin` — create the key ring / key and set the key's IAM policy

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `google_project_name` : the **service** project id — from **step 2.1** output `service_project_id`
- `google_service_project_number` : the service project number — from **step 2.1** output `service_project_number`; used to build the service-agent emails the key is granted to

**✍️ Your decisions this phase:**

- `kms_keyring_name` / `kms_key_name` : names for the key ring and CMEK key
- `google_service_account_email` : the security SA this config impersonates
- `google_region` : the region — a decision, but it **must be the same** across every phase

**📋 Fixed lookups** — none.

## Outputs

Copied into the next phase's `terraform.tfvars` (or wired via `terraform_remote_state`):

- `cmek_key_id` : the full KMS resource id (`projects/…/cryptoKeys/…`) → **step 2.4 (workspace)**, which registers it with Databricks

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

Then hand `cmek_key_id` to step 2.4.

## Additional info

step 2.3 owns the encryption key on its own, so the security team controls it independently of everyone else. The key lives in the **service project** because that's where the resources it encrypts live — the workspace's GCE disks and GCS buckets — so it's the service project's own Google-managed agents that do the encrypting. We grant `cryptoKeyEncrypterDecrypter` to two of them: the `compute-system` agent (VM disks) and the `gs-project-accounts` agent (GCS). Those agents must already exist, which is why step 2.1 provisions them first.

The only thing that leaves this phase is the key id — step 2.4 takes it from here and registers it with the workspace for **both** the STORAGE and MANAGED_SERVICES use cases.

### STORAGE vs MANAGED_SERVICES — one key, two encryptors, two grants

The two use cases protect data in two different places, encrypted by two different identities — which is why the grants are split across two steps:

| Use case | What it encrypts | Where it lives | Who does the encrypting | Grant made in |
|---|---|---|---|---|
| **STORAGE** | Workspace GCS bucket (DBFS root, system data) + cluster VM persistent disks | Your **service project** (data plane) | The service project's **Google service agents** (`compute-system`, `gs-project-accounts`) | **This step (2.3)** |
| **MANAGED_SERVICES** | Notebook source, command results, secrets, Databricks SQL history | Databricks' **control plane** | The **Databricks workspace SA** (`db-…`) | **step 2.6** |

The principle: whoever physically writes the data at rest is the one that needs `cryptoKeyEncrypterDecrypter`. For STORAGE that's Google's own services (so we grant their agents, here). For MANAGED_SERVICES that's Databricks (so the workspace SA gets the grant — but only in step 2.6, because the SA doesn't exist until the workspace is created in step 2.4). In a least-privilege deployment Databricks does **not** grant itself: the step-2.4 key registration only calls the account API and never touches the key's IAM.
