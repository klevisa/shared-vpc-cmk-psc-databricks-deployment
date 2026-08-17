# Phase 2 — service-cmek (Cloud Security / KMS)

**Creates (SERVICE project):** the CMEK key ring + crypto key, and grants
`cryptoKeyEncrypterDecrypter` to the service project's `compute-system` (VM disks) and
`gs-project-accounts` (GCS) agents. Runs **in parallel with Phase 1**.

**Identity:** `roles/cloudkms.admin` on the SERVICE project. Impersonated via
`google_service_account_email`.

**Inputs:** service project id + number, region, key ring / key names.

**Output → Phase 3:** `cmek_key_id` (full KMS resource id).

> The service agents must already exist (Phase 0 / Cloud Foundation) or the IAM grants
> fail with `400 does not exist`. The `MANAGED_SERVICES` grant is added by Databricks at
> registration in Phase 3.

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```
