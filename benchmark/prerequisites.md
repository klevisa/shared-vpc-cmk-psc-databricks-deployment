# Phase 5 — Benchmark setup (GCP-side + service principals)

> ← Back to the [PoC playbook](../README.md) · [Benchmark](README.md)

The benchmark run is just jobs + collectors, but the **cost** numbers and the run
orchestration depend on a few GCP-side things and **five principals** existing first. These
are one-time setups, mostly owned by the cloud/billing team.

## 1. A BigQuery billing export (standard *or* detailed)

GCP does not expose per-VM cost through an API — it exposes it by **exporting billing data
to BigQuery**, which must be turned on (it is off by default, and **not retroactive** — it
only captures usage from the day it's enabled, so it must be on **before** the benchmark runs).

1. GCP console → **Billing → Billing export → BigQuery export** (or confirm it's already on).
2. Note the **dataset** the export lands in (e.g. `billing_export`).
3. **Either export works — attribution is by the `run_id` label, and both carry a `labels`
   array you can group by:**
   - **Standard usage cost** → `gcp_billing_export_v1_<BILLING_ACCOUNT_ID>` — **sufficient**,
     and the lower-friction option.
   - **Detailed usage cost** → `gcp_billing_export_resource_v1_...` — also fine; it *only*
     adds per-VM identifiers (`resource.name`), which this PoC does **not** use.
   > The export is **billing-account-wide** — it can't be confined to labels or projects, so
   > the whole account's cost lands in that dataset. That's why access is locked to the
   > billing team and the data-collector SA only ever sees the scoped view (§2).
4. Expect **latency**: rows land hours (up to ~a day) after usage — which is why the
   collectors are **run on demand after the runs settle**.

Cost attribution works because each engine's VMs carry the run labels:
- **Databricks** — the cluster `custom_tags` (`project`, `engine`, `run_id`) propagate to the
  GCE VM labels; `run_id` is injected via `{{job.run_id}}` (= `usage_metadata.job_run_id`).
- **Dataproc** — the submit orchestration (`src/submit_dataproc.py`) labels each job
  `project`, `engine=dataproc`, `run_id=<dataproc job id>` (plus the auto `goog-dataproc-*`).

> **Verify the labels land in the export** before relying on it — coverage can vary by
> service: `SELECT * FROM <export>, UNNEST(labels) l WHERE l.key = 'run_id' LIMIT 10`. Labels
> only attach usage from when they're applied forward. Standard rows are SKU-aggregated, which
> is fine here because each run's cluster VMs share one `run_id`.

## 2. Create a **scoped authorized view** over the export

Do **not** give the data-collector SA the whole billing export. Create an
[authorized view](https://cloud.google.com/bigquery/docs/authorized-views) that pre-filters
to the benchmark rows and exposes the shape the collectors expect (`run_id, platform,
engine, cost`):

```sql
CREATE VIEW `billing-project.benchmark_billing.vm_cost_by_run` AS
SELECT
  (SELECT value FROM UNNEST(labels) WHERE key = 'run_id')  AS run_id,
  (SELECT value FROM UNNEST(labels) WHERE key = 'engine')  AS engine,
  CASE WHEN (SELECT value FROM UNNEST(labels) WHERE key = 'engine') = 'dataproc'
       THEN 'dataproc' ELSE 'databricks' END               AS platform,
  cost
-- standard export table; for the detailed export use gcp_billing_export_resource_v1_XXXXXX
FROM `billing-project.billing_export.gcp_billing_export_v1_XXXXXX`
WHERE service.description = 'Compute Engine'
  AND (SELECT value FROM UNNEST(labels) WHERE key = 'project') = 'dataproc-vs-photon';
```

The `UNNEST(labels)` shape is identical for both exports, so the view (and the collectors)
don't care which one is enabled.

The **data-collector SA** is granted read on **only this view** (plus `bigquery.jobUser` to
run the query) — it never sees the rest of the billing export.

## 3. Two GCP service accounts (cloud identities)

Distinct from the Databricks SPs in §5. Each is a **GCP service account** whose SA-key JSON
lives in the Databricks secret scope; the Databricks SP that needs it reads it via
`dbutils.secrets`.

| GCP SA | Read by | GCP access |
|---|---|---|
| `gcp-dataproc-runner` | `bench-runner` | **project-level** in the Dataproc project: `dataproc.clusters.create` + `dataproc.clusters.delete` (ephemeral per-run cluster) + `dataproc.jobs.create` + `dataproc.jobs.setIamPolicy`; plus `iam.serviceAccounts.actAs` on the cluster's VM service account |
| `gcp-data-collector` | `bench-collector` | read (`bigquery.dataViewer`) on the authorized view (§2) + `bigquery.jobUser` to run the query + `dataproc.jobs.get` (granted per-job by the runner — §4) |

Store each key in its **own scope** (one per SA):
```bash
databricks secrets create-scope benchmark_runner
databricks secrets put-secret benchmark_runner   gcp_dataproc_runner_key --string-value "$(cat dataproc-runner-key.json)"
databricks secrets create-scope benchmark_collector
databricks secrets put-secret benchmark_collector gcp_data_collector_key  --string-value "$(cat data-collector-key.json)"
```

> **Two scopes, one key each — deliberately.** Secret ACLs are per *scope*, not per secret, so
> a single shared scope would let both SPs read *both* keys. Splitting into
> `benchmark_runner` and `benchmark_collector` keeps `bench-runner` able to read only the
> dataproc-runner key and `bench-collector` only the data-collector key. (Bundle vars
> `runner_secret_scope` / `collector_secret_scope`.)

## 4. Ephemeral cluster + the Dataproc `jobs.get` role (automated at submit)

- Create a **custom role** with just `dataproc.jobs.get` (the bundle's `dataproc_jobs_get_role`).
- The submit orchestration (`src/submit_dataproc.py`, run as `bench-runner` via the
  dataproc-runner SA) does everything per run:
  1. **creates an ephemeral Dataproc cluster** labeled `project`/`engine=dataproc`/`run_id`,
     hardware matched to the Databricks job clusters, auto-deleted after idle. Putting `run_id`
     on the **cluster** is what lands it on the VM billing rows — Dataproc *job* labels don't
     reach the VMs — so per-run VM cost is attributable and concurrency-proof;
  2. submits the file to it (job id = `run_id`);
  3. grants the **data-collector SA** the `jobs.get` role on **that job only** (per-job IAM).
- These are project-scoped Dataproc permissions (create/delete cluster, submit job, set job
  IAM; see §3) — not cluster-scoped, and Dataproc jobs can't be IAM-conditioned by region — so a
  **dedicated PoC Dataproc project** is the tightest boundary. You grant these to the runner SA.
- **No manual steps** — cluster create, submit, per-job IAM, and run recording all happen in
  the job; the cluster auto-deletes when idle.

## 5. Databricks service principals (runner / collector / analyst)

Three **Databricks** service principals, created once by an **account admin**. They run as
separation of duties — people only *trigger* jobs (`CAN_MANAGE_RUN`) and *view* the dashboard.

| SP | Runs | Access |
|---|---|---|
| `bench-runner` | the workload jobs **and** the Dataproc submit | reads `source_data_ro`, writes `analytics.workloads`; READ on the `benchmark_runner` scope only |
| `bench-collector` | `collect_dbx` / `collect_dataproc` | writes `analytics.benchmark`, reads system tables; READ on the `benchmark_collector` scope only |
| `bench-analyst` | the dashboard | reads `analytics.benchmark` only |

Steps (account admin, then catalog owner):

1. **Create the three SPs** and assign each to the workspace (USER). Put their application
   ids into `databricks.yml` (`runner_sp` / `collector_sp` / `analyst_sp`) for `run_as` and
   the dashboard.
2. **Runner entitlement** — grant `bench-runner` **allow-cluster-create** (no cluster policies).
3. **System-table schemas** are enabled on the metastore in **Phase 1** (see
   [`../databricks-account-setup`](../databricks-account-setup/README.md)). The collector reads
   only `billing` (DBU + `list_prices`) and `lakeflow` (`job_run_timeline` for runtime) —
   confirm those two are enabled.
4. **Run the grants** — as the `analytics` catalog owner, run [`sql/grants.sql`](sql/grants.sql)
   with each SP's application id substituted for `:runner` / `:collector` / `:analyst`.
5. **Secret ACLs** — each SP READ on **only its own** scope (§3):
   ```bash
   databricks secrets put-acl benchmark_runner    <bench-runner-app-id>    READ
   databricks secrets put-acl benchmark_collector <bench-collector-app-id> READ
   ```
