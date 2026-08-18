# Phase 2 — service-cmek (Cloud Security / KMS)

## What it does

Creates the customer-managed encryption key (CMEK) in the **service project** and grants the project's Google-managed agents permission to use it:

- **Key ring + crypto key** — the CMEK the workspace's storage and managed services are encrypted with
- **Service-agent grants** — `cryptoKeyEncrypterDecrypter` to the service project's:
  - `compute-system` agent (VM disks)
  - `gs-project-accounts` agent (GCS)

Runs **in parallel with Phase 1** (they don't depend on each other).

## Pre-reqs

- **Phase 0 (`foundation/`) has run** — the service project exists, its APIs are enabled, and its GCS/compute service agents exist (or the grants fail with `400 … does not exist`).
- You have Phase 0's outputs `service_project_id` and `service_project_number`.

## Privileges needed

On the impersonated security SA (`google_service_account_email`), against the **service** project:

- `roles/cloudkms.admin` — create the key ring / key and set the key's IAM policy

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `google_project_name` : the **service** project id — from **Phase 0** output `service_project_id`
- `google_service_project_number` : the service project number — from **Phase 0** output `service_project_number`; used to build the service-agent emails the key is granted to

**✍️ Your decisions this phase:**

- `kms_keyring_name` / `kms_key_name` : names for the key ring and CMEK key
- `google_service_account_email` : the security SA this config impersonates
- `google_region` : the region — a decision, but it **must be the same** across every phase

**📋 Fixed lookups** — none.

## Outputs

Copied into the next phase's `terraform.tfvars` (or wired via `terraform_remote_state`):

- `cmek_key_id` : the full KMS resource id (`projects/…/cryptoKeys/…`) → **Phase 3 (databricks-account)**, which registers it with Databricks

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

Then hand `cmek_key_id` to Phase 3.

## Additional info

Phase 2 owns the encryption key on its own, so the security team controls it independently of everyone else. The key lives in the **service project** because that's where the resources it encrypts live — the workspace's GCE disks and GCS buckets — so it's the service project's own Google-managed agents that do the encrypting. We grant `cryptoKeyEncrypterDecrypter` to two of them: the `compute-system` agent (VM disks) and the `gs-project-accounts` agent (GCS). Those agents must already exist, which is why Phase 0 provisions them first.

We register the key for both **STORAGE** and **MANAGED_SERVICES** use cases in Phase 3; the STORAGE grants are the ones set here, and Databricks adds its own **MANAGED_SERVICES** grant automatically when the key is registered. The only thing that leaves this phase is the key id — Phase 3 takes it from here and wires it into the workspace so both storage and managed services are CMEK-encrypted.
