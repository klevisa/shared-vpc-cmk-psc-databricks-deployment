# Phase 5 — Benchmark setup (GCP-side + service principals)

> ← Back to the [PoC playbook](../README.md) · [Benchmark](README.md)

The benchmark run is just jobs + collectors, but the **cost** numbers and the run
orchestration depend on a few GCP-side things and **five principals** existing first. These
are one-time setups, mostly owned by the client's cloud/billing team.

## 1. Enable the BigQuery **detailed** billing export

GCP does not expose per-VM cost through an API — it exposes it by **exporting billing data
to BigQuery**, which you must turn on (it is off by default, and **not retroactive** — it
only captures usage from the day you enable it, so do this **before** the benchmark runs).

1. GCP console → **Billing → Billing export → BigQuery export**.
2. Choose a **dataset** to receive the export (e.g. `billing_export`, in a project you control).
3. Enable **Detailed usage cost** (the *resource-level* export). Required — the *standard*
   export lacks the per-resource `labels`/`resource.name` needed to attribute cost to a VM.
   This creates: `<billing-project>.<dataset>.gcp_billing_export_resource_v1_<BILLING_ACCOUNT_ID>`.
4. Expect **latency**: rows land hours (up to ~a day) after usage — which is why the
   collectors are **run on demand after the runs settle**.

Cost attribution works because each engine's VMs carry our labels:
- **Databricks** — the cluster `custom_tags` (`project`, `engine`, `run_id`) propagate to the
  GCE VM labels; `run_id` is injected via `{{job.run_id}}` (= `usage_metadata.job_run_id`).
- **Dataproc** — the submit orchestration (`src/submit_dataproc.py`) labels each job
  `project`, `engine=dataproc`, `run_id=<dataproc job id>` (plus the auto `goog-dataproc-*`).

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
FROM `billing-project.billing_export.gcp_billing_export_resource_v1_XXXXXX`
WHERE service.description = 'Compute Engine'
  AND (SELECT value FROM UNNEST(labels) WHERE key = 'project') = 'dataproc-vs-photon';
```

The **data-collector SA** is granted read on **only this view** (plus `bigquery.jobUser` to
run the query) — it never sees the rest of the billing export.

## 3. Two GCP service accounts (cloud identities)

Distinct from the Databricks SPs in §5. Each is a **GCP service account** whose SA-key JSON
lives in the Databricks secret scope; the Databricks SP that needs it reads it via
`dbutils.secrets`.

| GCP SA | Read by | GCP access |
|---|---|---|
| `gcp-dataproc-runner` | `bench-runner` | `dataproc.jobs.create` on the client's cluster + `dataproc.jobs.setIamPolicy` (to grant the collector per-job) |
| `gcp-data-collector` | `bench-collector` | read on the authorized view (§2) + `dataproc.jobs.get` (granted per-job by the runner — §4) |

Store both keys in the secret scope:
```bash
databricks secrets create-scope benchmark
databricks secrets put-secret benchmark gcp_dataproc_runner_key --string-value "$(cat dataproc-runner-key.json)"
databricks secrets put-secret benchmark gcp_data_collector_key  --string-value "$(cat data-collector-key.json)"
```

> **Secret ACLs are per *scope*, not per secret.** If both `bench-runner` and
> `bench-collector` hold READ on one scope, each can read *both* keys. For strict isolation
> (runner can't read the collector's key, and vice versa), use **two scopes** — one per key —
> and give each SP READ on only its own. The bundle's `secret_scope` variable points at one
> scope by default; split it if the client requires the tighter boundary.

## 4. The Dataproc `jobs.get` role + per-job IAM (automated at submit)

- Create a **custom role** with just `dataproc.jobs.get` (the bundle's `dataproc_jobs_get_role`).
- You do **not** grant it broadly. The submit orchestration (`src/submit_dataproc.py`, run as
  `bench-runner` via the dataproc-runner SA) grants the **data-collector SA** that role on
  **each job it submits** — per-job IAM, in code — so the collector reads only the benchmark
  jobs' runtimes. This needs the dataproc-runner SA to hold `dataproc.jobs.create` and
  `dataproc.jobs.setIamPolicy` on the client's cluster; the client grants those.
- There is **no manual per-job step** — it's part of the submit.

## 5. Databricks service principals (runner / collector / analyst)

Three **Databricks** service principals, created once by an **account admin**. They run as
separation of duties — people only *trigger* jobs (`CAN_MANAGE_RUN`) and *view* the dashboard.

| SP | Runs | Access |
|---|---|---|
| `bench-runner` | the workload jobs **and** the Dataproc submit | reads `customer_data_ro`, writes `analytics.workloads`; READ on the dataproc-runner key |
| `bench-collector` | `collect_dbx` / `collect_dataproc` | writes `analytics.benchmark`, reads system tables; READ on the data-collector key |
| `bench-analyst` | the dashboard | reads `analytics.benchmark` only |

Steps (account admin, then catalog owner):

1. **Create the three SPs** and assign each to the workspace (USER). Put their application
   ids into `databricks.yml` (`runner_sp` / `collector_sp` / `analyst_sp`) for `run_as` and
   the dashboard.
2. **Runner entitlement** — grant `bench-runner` **allow-cluster-create** (no cluster policies).
3. **Enable the system schemas** the collector reads (metastore/account admin):
   ```bash
   databricks system-schemas enable <metastore-id> billing
   databricks system-schemas enable <metastore-id> compute
   databricks system-schemas enable <metastore-id> query
   databricks system-schemas enable <metastore-id> access
   ```
4. **Run the grants** — as the `analytics` catalog owner, run [`sql/grants.sql`](sql/grants.sql)
   with each SP's application id substituted for `:runner` / `:collector` / `:analyst`.
5. **Secret ACLs** — `bench-runner` READ on the dataproc-runner key, `bench-collector` READ
   on the data-collector key (per scope — see the note in §3):
   ```bash
   databricks secrets put-acl benchmark <bench-runner-app-id>    READ
   databricks secrets put-acl benchmark <bench-collector-app-id> READ
   ```
