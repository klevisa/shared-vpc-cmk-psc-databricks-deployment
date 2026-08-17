# Phase 0 — foundation (Cloud Foundation / Landing Zone)

**Creates / establishes:**
- the **service project** (the host project is assumed to already exist and is only referenced);
- the **required APIs** on both the host and service projects;
- the **Shared VPC relationship** — enables the host and attaches the service project;
- the **GCS service agent** on the service project (so Phase 2's CMEK grant doesn't 400;
  the compute service agent is created by enabling the Compute API).

**Identity:** org/folder-level standing — `resourcemanager.projectCreator`, `billing.user`,
`compute.xpnAdmin`, `resourcemanager.projectIamAdmin`, `serviceusage.serviceUsageAdmin`.
Impersonated via `google_service_account_email`.

**Inputs:** existing host project id, the service project id to create, org **or** folder id,
billing account, region (APIs default sensibly).

**Outputs → Phases 1–3:** `host_project`, `service_project_id`, `service_project_number`.

> This is the shared foundation another team normally owns. It runs **once** and rarely
> changes. The remaining phases build the network, keys, and workspace on top of it.

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```
