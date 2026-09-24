# Phase 5 — Benchmark setup (GCP-side + service principals)

> ← Back to the [PoC playbook](../README.md) · [Benchmark](README.md)

The benchmark is orchestrated by **Airflow** and measured by a single **cost collector**. The
Dataproc jobs run in the background — Airflow senses each one finishing, copies its exact input to
**`poc_bucket`**, and triggers the Databricks runs. The cost numbers depend on a few GCP-side
things and a small set of principals existing first. These are one-time setups, mostly owned by the
cloud/billing team.

## 1. A BigQuery billing export (standard *or* detailed)

GCP does not expose per-VM cost through an API — it exposes it by **exporting billing data to
BigQuery**, which must be turned on (it is off by default, and **not retroactive** — it only
captures usage from the day it's enabled, so it must be on **before** the benchmark runs).

1. GCP console → **Billing → Billing export → BigQuery export** (or confirm it's already on).
2. Note the **dataset** the export lands in (e.g. `billing_export`).
3. **Standard usage cost** (`gcp_billing_export_v1_<BILLING_ACCOUNT_ID>`) is **sufficient** — the
   `goog-dataproc-*` and our custom labels live in the `labels` array, present in the standard
   export (they are *not* `system_labels`, which only carry `compute.googleapis.com/*` keys). You do
   **not** need the detailed/resource export.
4. Expect **latency**: rows land hours (up to ~a day) after usage — which is why the collector is
   **run on demand after the runs settle**.

### Cost attribution: two labels on both platforms' compute

We stamp **two** labels on **both** platforms' compute, doing three jobs:

| Label | Applied by | Purpose |
|---|---|---|
| `poc=photon-poc` | Airflow (Dataproc cluster) + bundle `custom_tags` (Databricks clusters) | **scope** — the only rows the view/SA can see |
| `engine` = `dataproc` / `photon` / `spark` | same | **platform + engine** — splits Dataproc vs Databricks, Photon vs Spark |
| `goog-dataproc-cluster-uuid` (auto) / `run_id` (Databricks `{{job.run_id}}`) | Dataproc / Databricks | **per-run** grouping key |

- **Databricks** — the cluster `custom_tags` (`poc`, `engine`, `run_id`) propagate to the GCE VM
  labels; `run_id` is injected via `{{job.run_id}}` (= `usage_metadata.job_run_id`).
- **Dataproc** — Airflow labels the **benchmarked cluster** `poc=photon-poc` + `engine=dataproc`
  at creation. A cluster label lands on **both** the Compute Engine VM/PD rows **and** the
  `Cloud Dataproc` licensing-fee rows (confirmed by GCP's docs — "filtering billing data to
  calculate Managed Service for Apache Spark costs" — and by the Dataproc author on
  [SO 51213085](https://stackoverflow.com/questions/51213085)). The auto `goog-dataproc-cluster-uuid`
  is the per-run key.

Two requirements follow:

- **Benchmarked Dataproc runs use an ephemeral, labeled cluster** — one per benchmark run, labeled
  `poc`+`engine`, auto-deleted on idle. A shared cluster can't be labeled distinctly and its VM cost
  can't be isolated per run (you'd fall back to core-second allocation). Airflow sets the labels when
  it creates the cluster.
- **Extract labels as scalar subqueries and group on a single key** (see §2). The flattened export
  repeats each cost once per label, and Dataproc stamps three `goog-dataproc-*` labels, so a
  `CROSS JOIN UNNEST(labels)` + `SUM(cost)` would triple-count.

## 2. Create a scoped, dedup-safe authorized view over the export

Do **not** give the collector SA the whole billing export. Create an
[authorized view](https://cloud.google.com/bigquery/docs/authorized-views) that pre-filters to the
benchmark rows (`poc=photon-poc`), splits platform + cost bucket, and extracts labels as **scalar
subqueries** so costs are not multiplied by the label count:

```sql
CREATE VIEW `billing-project.benchmark_billing.poc_cost` AS
SELECT
  -- per-run key: dataproc cluster uuid, else the Databricks job_run_id
  COALESCE(
    (SELECT value FROM UNNEST(labels) WHERE key = 'goog-dataproc-cluster-uuid'),
    (SELECT value FROM UNNEST(labels) WHERE key = 'run_id')
  )                                                              AS run_id,
  (SELECT value FROM UNNEST(labels) WHERE key = 'engine')        AS engine,
  CASE WHEN (SELECT value FROM UNNEST(labels) WHERE key = 'engine') = 'dataproc'
       THEN 'dataproc' ELSE 'databricks' END                    AS platform,
  CASE WHEN service.description = 'Cloud Dataproc' THEN 'dataproc_license'
       WHEN service.description = 'Compute Engine'  THEN 'compute_vm_pd'
       ELSE service.description END                             AS cost_bucket,
  SUM(cost)                                                      AS cost
-- standard export table; for the detailed export use gcp_billing_export_resource_v1_XXXXXX
FROM `billing-project.billing_export.gcp_billing_export_v1_XXXXXX`
WHERE (SELECT value FROM UNNEST(labels) WHERE key = 'poc') = 'photon-poc'   -- scope
GROUP BY run_id, engine, platform, cost_bucket;
```

Per run this yields the breakdown the dashboard wants:
- **Dataproc** → `compute_vm_pd` (VM + persistent disk) **+** `dataproc_license` (the managed-service fee)
- **Databricks** → `compute_vm_pd` (VM + persistent disk); DBU $ is added later from system tables

The **collector SA** is granted read on **only this view** (`bigquery.dataViewer`) plus
`bigquery.jobUser` to run the query — it never sees the rest of the billing export, and it has **no**
Dataproc permission at all.

> **Verify the labels land before relying on it** — coverage can vary by service:
> ```sql
> SELECT service.description,
>        (SELECT value FROM UNNEST(labels) WHERE key='goog-dataproc-cluster-uuid') AS uuid,
>        COUNT(*) rows, SUM(cost) cost
> FROM `…gcp_billing_export_v1_XXXXXX`
> WHERE (SELECT value FROM UNNEST(labels) WHERE key='poc') = 'photon-poc'
> GROUP BY 1, 2 ORDER BY 1;
> ```
> Confirm a `Cloud Dataproc` row appears with a non-null uuid. If a given window shows the licensing
> SKU **un-labeled**, fall back to the **analytical premium** — Airflow knows the cluster shape +
> lifetime, so `premium = total_vCPUs × uptime_hrs × ~$0.01` (confirm the rate) is deterministic and
> reconciled against the view.

## 3. The collector service account

| GCP SA | Used by | GCP access |
|---|---|---|
| `gcp-data-collector` | `bench-collector`'s collector job cluster | `bigquery.dataViewer` on the authorized view (§2) + `bigquery.jobUser` to run the query. **No `dataproc.*`**. |

The collector is **keyless**: its job cluster runs on GCE VMs attached to `gcp-data-collector`, and
the code authenticates as that SA via Application Default Credentials (ADC) through the metadata
server. No key, no secret scope.

1. **Create `gcp-data-collector`** (no key).
2. **Grant its BigQuery roles**, time-boxed to `poc_expiry` (`2026-12-31T00:00:00Z`, the shared
   `request.time` end date across the PoC configs) so access lapses on the PoC end date:
   ```bash
   gcloud projects add-iam-policy-binding <BILLING_PROJECT> \
     --member="serviceAccount:gcp-data-collector@<proj>.iam.gserviceaccount.com" \
     --role="roles/bigquery.jobUser" \
     --condition='expression=request.time < timestamp("2026-12-31T00:00:00Z"),title=poc-expiry'
   # plus roles/bigquery.dataViewer on the authorized view (§2)
   ```
3. **Attach it to the collector job cluster** (`resources/collectors.yml`):
   ```yaml
   new_cluster:
     gcp_attributes:
       google_service_account: gcp-data-collector@<proj>.iam.gserviceaccount.com
   ```
4. **`actAs`** — the **workspace SA** needs `roles/iam.serviceAccountUser` on `gcp-data-collector`
   for the attach. Add it in Terraform (not a manual gcloud grant, so it stays in state and is torn
   down by destroy): append the collector SA to `additional_actas_service_accounts` in
   [`workspace-sa-roles/`](../workspace-setup/workspace-sa-roles/README.md) and re-apply. The binding
   is resource-level and time-boxed by `poc_expiry`.
   ```hcl
   # workspace-sa-roles/terraform.tfvars
   additional_actas_service_accounts = ["gcp-data-collector@<proj>.iam.gserviceaccount.com"]
   ```
   > **General rule:** the workspace SA needs `actAs` on **every** SA a cluster runs as — the compute
   > SA and this collector SA. Any future cluster-attached SA is added the same way, in the phase that
   > introduces it.
5. **Code uses ADC** (`src/bq_billing.py`):
   ```python
   from google.cloud import bigquery
   client = bigquery.Client(project="<billing-project>")   # ADC = the cluster's attached SA
   ```

## 4. Airflow (Cloud Composer) — orchestration + copy prerequisites

The DAG, per benchmarked Dataproc job:

1. **senses** the Dataproc job finishing (downstream of the `DataprocSubmitJobOperator`, or a
   `DataprocJobSensor`), and **captures its runtime** (`status_history` RUNNING→terminal) — Airflow
   owns the job, so no collector grant is needed;
2. **captures the exact input** — lists the (closed, immutable) input partition and writes a
   `manifest.csv` (object name + generation + CRC32C + size); computes a **fingerprint**;
3. **STS copy** into a run-scoped prefix `gs://poc_bucket/benchmark/<benchmark_run_id>/`,
   **manifest-driven**;
4. **verify gate** — recompute the fingerprint on the destination; **fail the DAG if it differs**;
5. **triggers the Databricks runs** (`DatabricksRunNowOperator`) for Photon and Spark, passing the
   tracking params (`benchmark_run_id`, `dataproc_job_id`, `cluster_uuid`, `dataproc_duration_s`,
   `input_window`, `manifest_uri`, `fingerprint`, `sts_job_id`).

Composer's service account needs:
- **Dataproc**: read the benchmarked job's status + set `poc`/`engine` labels on the ephemeral
  benchmark cluster it creates for the run;
- **GCS**: object read on the source bucket (manifest) and object admin on `poc_bucket`;
- **STS**: `storagetransfer.jobs.create` / `.run`; the **STS service agent**
  (`project-<PROJNUM>@storage-transfer-service.iam.gserviceaccount.com`) needs `objectViewer` on
  source and `objectAdmin` on `poc_bucket`. `poc_bucket` uses **Google-managed** encryption, so **no
  CMEK grant is needed**; CMEK enters only if the **source** bucket sets a customer-managed default
  key, in which case grant the STS agent `cryptoKeyEncrypterDecrypter` (decrypt) on that key;
- **VPC-SC**: an ingress/egress rule admitting STS across the perimeter between the source and
  `poc_bucket` projects (same class of change as the storage-credential SA in the data-access phase);
- **Databricks**: a connection/credential (PAT or SP OAuth) with `CAN_MANAGE_RUN` on the benchmark
  job, to trigger it.

> The copy is **one-time, batch, manifest-driven** (Dataproc finishes → then copy), never a
> continuous sync, and **never** deletes at source.

## 5. Databricks service principals (runner / collector / analyst)

Three **Databricks** service principals, created once by an **account admin**. People only *trigger*
(via Airflow) and *view*.

| SP | Runs | Access |
|---|---|---|
| `bench-runner` | the Databricks Photon/Spark workloads (triggered by Airflow); writes the tracking row + appends Photon coverage | reads `source_data_ro`, writes `analytics.workloads`, writes `analytics.benchmark.benchmark_runs` (tracking) + `analytics.benchmark.photon_coverage`. Needs no GCP key. |
| `bench-collector` | the cost collector | writes `analytics.benchmark`, reads system tables (`billing`, `lakeflow`); GCP access via the collector job cluster's attached SA (§3, keyless) — no secret scope |
| `bench-analyst` | the dashboard | reads `analytics.benchmark` only |

Steps (account admin, then catalog owner):

1. **Create the three SPs** and assign each to the workspace (USER). Put their application ids into
   `databricks.yml` (`runner_sp` / `collector_sp` / `analyst_sp`) for `run_as` and the dashboard.
   Give the **Airflow trigger identity** `CAN_MANAGE_RUN` on the benchmark job.
2. **Runner entitlement** — grant `bench-runner` **allow-cluster-create** (no cluster policies). Set
   the Databricks job clusters' `custom_tags` to `poc=photon-poc` + `engine` (+ `run_id` via
   `{{job.run_id}}`) so their VM cost lands in the same scoped view.
3. **System-table schemas** are enabled on the metastore in **Phase 1**. The collector reads only
   `billing` (DBU + `list_prices`) and `lakeflow` (`job_run_timeline` for Databricks runtime) —
   confirm those two are enabled.
4. **Run the grants** — as the `analytics` catalog owner, run [`sql/grants.sql`](sql/grants.sql) with
   each SP's application id substituted for `:runner` / `:collector` / `:analyst`.
5. **Collector GCP access** — keyless (§3): attach `gcp-data-collector` to the collector job cluster
   and grant the workspace SA `actAs` on it. No secret scope.
