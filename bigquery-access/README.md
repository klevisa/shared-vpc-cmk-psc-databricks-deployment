# BigQuery access — keyless connector SA (POC1a)

> ← [PoC playbook](../README.md)

## Why this exists
Databricks' **BigQuery Lakehouse Federation connection** takes a **GCP service-account key
JSON** (stored in a Databricks secret) — there is **no keyless option**, which conflicts with
Yahoo's no-keys rule. Because POC1a runs on **classic clusters** (not serverless), the keyless
path is the **`spark-bigquery-connector`** authenticating as the **cluster's attached Google
SA** via ADC. This root creates that SA and grants it least-privilege BigQuery access.

> Use UC Lakehouse Federation (the keyed connection) only if you specifically need BigQuery
> governed as a UC **foreign catalog**; then treat the key as a written exception (secret-stored,
> least-privilege, rotated). For read+write from Spark, the connector below avoids the key.

## What it creates / grants
- **`databricks-bq-connector` SA** in the service project (keyless — no key issued).
- **Dataset-scoped:** `bigquery.dataViewer` (+ `bigquery.dataEditor` when `read_write = true`) on the target dataset only.
- **Project-scoped, `poc_expiry`-bound:** `bigquery.jobUser` (run queries) + `bigquery.readSessionUser` (the connector's Storage Read API).

## Wiring (three places — the SA email is the `bq_connector_sa_email` output)
1. **Attach to the cluster:** set `gcp_attributes.google_service_account = <sa email>` on the classic clusters that use the connector.
2. **Cluster policy allow-list:** add the SA to your workload cluster policy's `gcp_attributes.google_service_account` allowlist (same pattern as `benchmark/resources/cluster_policy.yml`).
3. **`actAs`:** add the SA to `additional_actas_service_accounts` in [`workspace-setup/workspace-sa-roles/`](../workspace-setup/workspace-sa-roles/README.md) so the workspace SA can attach it (resource-scoped, time-boxed) — the same grant the node and collector SAs get.

## Run
```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

## Verify at deploy
- A classic cluster attached to the SA can **read and write** the target dataset via the connector (no key).
- `read_write = false` gives a read-only SA (no `dataEditor`).
- Indirect writes (via a GCS temp bucket) additionally need object access on that bucket — grant it there if you use indirect write mode.

## Teardown
`terraform destroy` removes the SA + all grants. The project-level grants also self-expire at `poc_expiry`.
