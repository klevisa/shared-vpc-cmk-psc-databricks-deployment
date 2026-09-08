# 2.7 · MANAGED_SERVICES CMEK grant — Cloud Security / KMS

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

Grants the Databricks **workspace service account** (minted by step 2.4) `cryptoKeyEncrypterDecrypter` on the CMEK key from step 2.3, so the **MANAGED_SERVICES** use case is actually authorized on the key.

- **Workspace-SA key grant** — the workspace SA encrypts the workspace's managed-services data (notebook source, command results, secrets, Databricks SQL query history) in the **control plane** with your key. Without this grant that data can't be encrypted/decrypted against the CMEK.

This is a Security-team handback: it could only happen **after** the workspace SA existed (step 2.4), but the CMEK key's IAM is owned by Security (step 2.3) — so it's the Security SA, not the network SA of step 2.6, that makes the grant.

## Why this is separate from step 2.3

Two use cases are registered on the key in step 2.4 (`use_cases = ["STORAGE","MANAGED_SERVICES"]`), and each is authorized by a **different** identity:

- **STORAGE** (workspace GCS buckets + cluster VM disks) is encrypted by the **service project's own Google service agents** (`compute-system`, `gs-project-accounts`). Those exist before the workspace, so their grants are made up front in **step 2.3**.
- **MANAGED_SERVICES** (control-plane data) is encrypted by the **Databricks workspace SA**, which doesn't exist until **step 2.4**. In a least-privilege deployment Databricks does **not** grant itself access to the key (the step-2.4 registration only calls the account API and never touches the key's IAM), so the grant is ours to make — here, once the SA is known.

## Pre-reqs

- **step 2.3 (`cmek/`) has run** — the CMEK key exists; you have its `cmek_key_id`.
- **step 2.4 (`workspace/`) has run** — the workspace SA exists; you have its `gcp_workspace_sa`.

## Privileges needed

On the impersonated security SA (`google_service_account_email`) — the **same identity as step 2.3** — against the **service** project:

- `roles/cloudkms.admin` — set the key's IAM policy

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `cmek_key_id` : the full KMS resource id — from **step 2.3** output `cmek_key_id`
- `gcp_workspace_sa` : the workspace service account — from **step 2.4** output `gcp_workspace_sa`

**✍️ Your decisions this phase:**

- `google_service_account_email` : the security SA this config impersonates (same as step 2.3)
- `google_project_name` : the **service** project id (same as step 2.3)
- `google_region` : the region — must be the same across every phase

**📋 Fixed lookups** — none.

## Outputs

None — this is a terminal grant; it authorizes the key rather than producing values for a downstream config.

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars
```

## Additional info

The grant is on the specific crypto **key** (not the key ring), which keeps it least-privilege — the workspace SA can use only this one key. If you ever rotate to a different CMEK key for managed services, re-run this step against the new `cmek_key_id`.
