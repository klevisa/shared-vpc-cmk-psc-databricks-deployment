# Phase 3 — databricks-account (Data / Databricks Platform)

**Creates (Databricks account):** the two PSC endpoint registrations, private access
settings, network config, CMEK registration, and the **workspace** (GCE/GCS land in the
SERVICE project). No GCP resources — this config talks only to the account API, so it
never touches the private workspace endpoint.

**Identity:** a Databricks **account admin** (impersonated via `google_service_account_email`).

**Inputs from Phase 1:** `vpc_network_project_id`, `vpc_name`, `node_subnet_name`,
`workspace_pe`, `relay_pe`. **From Phase 2:** `cmek_key_id`. Plus account id, workspace
name, service project, region, `public_access_enabled`.

**Outputs → Phase 4:** `workspace_id`, `workspace_url`, `gcp_workspace_sa`.

> After apply, re-check Phase 1's PSC status outputs — registering the endpoints here
> flips them **PENDING → ACCEPTED**. No workspace admin is created; see the delegated-admin
> note in `databricks.tf`.

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```
