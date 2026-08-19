# Benchmark prerequisites (GCP-side setup)

The benchmark itself is just jobs + collectors, but the **cost** numbers depend on a few
GCP-side things existing first. These are one-time setups, mostly owned by the customer's
cloud/billing team.

## 1. Enable the BigQuery **detailed** billing export

GCP does not expose per-VM cost through an API — it exposes it by **exporting billing data
to BigQuery**, which you must turn on (it is off by default, and it is **not retroactive** —
it only captures usage from the day you enable it, so do this **before** the benchmark runs).

1. In the GCP console: **Billing → Billing export → BigQuery export**.
2. Choose a **dataset** to receive the export (create one, e.g. `billing_export`, in a
   project you control — ideally the same region you query from).
3. Enable **Detailed usage cost** (the *resource-level* export). This is required — the
   *standard* export does **not** carry the per-resource `labels`/`resource.name` needed to
   attribute cost to a specific VM. Enabling it creates the table:
   ```
   <billing-project>.<dataset>.gcp_billing_export_resource_v1_<BILLING_ACCOUNT_ID>
   ```
4. Expect **latency**: rows land hours (sometimes up to ~a day) after usage. This is why the
   collectors are **run on demand after the runs settle**, not on a schedule.

Cost attribution works because each engine's compute VMs carry our labels:
- **Databricks** — the cluster `custom_tags` (`project`, `engine`, `run_id`) propagate to the
  GCE VM labels. `run_id` is injected via the `{{job.run_id}}` dynamic reference, so it equals
  `system.billing.usage.usage_metadata.job_run_id`.
- **Dataproc** — the submitter labels the cluster/job with `project`, `engine=dataproc`, and
  `run_id=<dataproc job id>` (plus the auto `goog-dataproc-*` labels).

## 2. Create a **scoped authorized view** over the export

Do **not** give the service principal the whole billing export. Instead create an
[authorized view](https://cloud.google.com/bigquery/docs/authorized-views) that pre-filters
to the benchmark rows and exposes a clean shape the collectors expect
(`run_id, platform, engine, cost`). Sketch:

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

The SP is then granted read on **only this view** — it can see benchmark VM cost and nothing
else. (Tighten further with more label filters as needed.)

## 3. The GCP service account (billing + Dataproc) — a *cloud* identity

This is distinct from the Databricks test SPs in §5. It's a **GCP service account** whose
**SA-key JSON is stored in a Databricks secret scope**; the collector reads it (via
`dbutils.secrets`) to authenticate to GCP. It needs exactly two things:

| Need | Grant | Scope |
|---|---|---|
| VM cost (both platforms) | read on the **authorized view** | just that view |
| Dataproc runtimes | custom role with **`dataproc.jobs.get`** only | **per-job** (see §4) |

Create the secret scope + store the key, and give **only** the collector SP READ on it:
```bash
databricks secrets create-scope benchmark
databricks secrets put-secret benchmark gcp_sp_key_json --string-value "$(cat sp-key.json)"
databricks secrets put-acl benchmark <collector-sp-app-id> READ
```

## 4. Dataproc per-job access (the submitter's extra step)

Dataproc IAM can't restrict `jobs.get` by name via conditions, so we bind **per job**: for
each benchmark Dataproc run, the **submitter** makes one extra call granting the SP
`dataproc.jobs.get` on **only that job** — the analog of the tag-scoped BigQuery view. This
is part of the submit flow (the job must exist before its policy can be set); the submitter
needs `dataproc.jobs.setIamPolicy`, the SP only receives `get`.

```bash
# after submitting a benchmark Dataproc job (id = $JOB_ID in $REGION):
gcloud dataproc jobs set-iam-policy $JOB_ID policy.json --region=$REGION
# policy.json binds roles/<custom-jobs-get-role> to serviceAccount:<sp>@... for that job
```

Fallback if per-job binding is too fiddly: bind the custom `jobs.get` role at the project
level (broader — sees all jobs in the region), or have the submitter record each job's
start/end so the SP needs **no** Dataproc access at all.

## 5. Databricks test service principals (runner / collector / analyst)

Three **Databricks** service principals, created once by an **account admin** (like the
catalog automation SA). They run as separation of duties — humans only *trigger* the jobs
(`CAN_MANAGE_RUN`) and *view* the dashboard; no person holds data/secret access.

| SP | Runs | Access |
|---|---|---|
| `bench-runner` | the benchmark jobs | reads `customer_data_ro`, writes `analytics.workloads` |
| `bench-collector` | `collect_dbx` / `collect_dataproc` | writes `analytics.benchmark`, reads system tables, READ on the secret scope |
| `bench-analyst` | dashboards | reads `analytics.benchmark` only |

Steps (account admin, then catalog owner):

1. **Create the three SPs** and assign each to the workspace (USER). Note each one's
   **application id** — put the runner + collector ids into `databricks.yml`
   (`runner_sp` / `collector_sp`) for `run_as`.
2. **Runner entitlement** — since there are no cluster policies, the runner needs to create
   its own job clusters: grant `bench-runner` the **allow-cluster-create** entitlement.
3. **Enable the system schemas** the collector reads (once, metastore/account admin):
   ```bash
   databricks system-schemas enable <metastore-id> billing
   databricks system-schemas enable <metastore-id> compute
   databricks system-schemas enable <metastore-id> query
   databricks system-schemas enable <metastore-id> access
   ```
4. **Run the grants** — as the `analytics` catalog owner, run [`sql/grants.sql`](sql/grants.sql)
   with each SP's application id substituted for `:runner` / `:collector` / `:analyst`.
5. **Secret ACL** — give `bench-collector` READ on the scope (the `put-acl` line in §3).

That's the whole identity setup — no governance layer, no cluster policies.
