# 7. Teardown

> ← Back to the [PoC playbook](../README.md)

**Purpose:** remove everything the PoC created, in the reverse order it was built.
**Owner:** the same teams that built each phase.
**Produces:** a clean account/projects and data-deletion evidence for the security review.

Each step is a `terraform destroy` of the config that owns those resources (its own state),
plus any account-level or GCP-console step. Run **top to bottom**.

> The **creator identity** (workspace-creator SA, its two read-only creator roles, and the
> workspace-creation VPC-SC ingress) was already removed at **step 2.9** during setup — it is
> not repeated here. See [`workspace-setup/creator-teardown/`](../workspace-setup/creator-teardown/README.md).

> **Time-boxing backstops this.** Every PoC-lifetime IAM grant carries a `poc_expiry`
> `request.time` condition, so it self-expires on the PoC end date regardless.

---

## Pre-flight

- `terraform state list` in each config; note the workspace id, workspace SA, compute SA, metastore id, bucket names, CMEK key id, catalog names, and SP application ids.
- Confirm nothing in the analytics bucket must be preserved.

> `system.access.audit` is a Unity Catalog **account-level** system table, not workspace state — it survives workspace deletion. Export it only before deleting the **metastore** (T9), and mind system-table retention (~365 days).

---

## Ordered steps

| Step | Removes | How | Owner |
|---|---|---|---|
| **T1** | **Benchmark (5–6)** | `databricks bundle destroy` (jobs + dashboard); `DROP SCHEMA analytics.benchmark CASCADE` + `analytics.workloads`; delete/disable the Airflow DAG and the Composer environment (if PoC-dedicated) + its SA grants; delete the STS transfer jobs + STS service-agent grants on source/`poc_bucket`; **delete `poc_bucket`** (copied input); drop the BigQuery view `poc_cost`; delete the 3 Databricks SPs (`bench-runner`/`collector`/`analyst`) + the Airflow trigger credential; delete `gcp-data-collector`. **No secret scopes to purge — the collector is keyless.** | Data Platform + Airflow/Dataproc |
| **T2** | **Serverless (4)** | `terraform destroy serverless-setup/` → unbind the NCC, delete the egress network policy; remove the serverless firewall-IP allowlist + its refresh automation | Net Sec + Data Platform |
| **T3** | **Data access (3)** | Reassign/drop objects owned by the automation SP first (a metastore admin can reassign). `terraform destroy data-access/` → drops both catalogs/schemas/external locations/storage credentials, **revokes the Mail-bucket `objectViewer`+`legacyBucketReader`**, revokes analytics `objectAdmin`, **deletes both VPC-SC ingress rules**, deletes the analytics bucket. Revoke the automation SP's `CREATE_*` grants; delete the automation SP | Data Platform + Net Sec + bucket owners |
| **T4** | **Workspace-SA operator grants (2.5–2.7)** | `terraform destroy` `cmek-workspace-grant/`, `post-workspace/`, `workspace-sa-roles/` → removes the CMEK grant, the network role + binding, the project/resource roles, and the compute-SA + collector-SA `actAs` bindings | Security + Net Sec + Cloud IAM |
| **T5** | **The workspace (2.4/2.8)** | `terraform destroy workspace/` → deletes the workspace (**releases the workspace SA + its buckets/VMs**), PSC regs, private-access settings, network config, CMEK registration, metastore assignment | Data Platform |
| **T6** | **CMEK (2.3)** | `terraform destroy cmek/` → removes the storage-agent grants; **schedule the key versions for destruction** (`gcloud kms keys versions destroy`), delete the keyring once destroyed | Security / KMS |
| **T7** | **Network (2.2)** | `terraform destroy network/` → PSC endpoints/forwarding rules, DNS records + zone, firewall, router/NAT, subnets, VPC; remove the STS VPC-SC ingress/egress rule if still present | Network Eng |
| **T8** | **Service project (2.1)** | `terraform destroy service-project/` → detach from the Shared VPC host, remove APIs; delete/shut down the service project | Cloud Foundation |
| **T9** | **Account (1)** | Revoke/delete the **account-admin SP** (all account-API work is done). The creator SA is already gone (2.9). Metastore: keep if region-shared, else delete. Databricks account/subscription: keep if org-wide | Databricks account admin |

> **Ordering notes.** T5 releases the workspace SA, so the T4 bindings become no-ops — still
> `destroy` T4 to remove the custom **role definitions**. KMS key versions are *scheduled* for
> destruction (24 h–30 d window); record the scheduled timestamp. Keep the deny-all default firewall
> until T7.

---

## Data-deletion evidence (attach to the ticket)

| Asset | Evidence |
|---|---|
| `poc_bucket` (copied Dataproc input) | `gcloud storage rm --recursive` output / empty `ls` |
| Analytics bucket | delete confirmation |
| Workspace-managed buckets | deleted with the workspace (T5) — capture the API response |
| CMEK key | `gcloud kms keys versions list` showing `DESTROY_SCHEDULED` + timestamp (renders CMEK-encrypted managed-services data unrecoverable) |
| Source / Mail data bucket | never modified — confirm the external location was `read_only=true` and no export jobs ran (`system.access.audit`) |
| UC catalogs | `DROP CATALOG … CASCADE` confirmation |
| Audit trail | UC account-level system table — survives workspace deletion; export only if the metastore is deleted (T9) |

## What stays

The metastore (if region-shared), the Databricks account/subscription (if org-wide), the
billing export (billing-account-wide), the source data bucket, and the human account admin.
