# 5–6. Benchmark Setup & Benchmark

> ← Back to the [PoC playbook](../README.md)

**Purpose:** deploy the agreed PySpark workloads, run them on Photon / Spark / Dataproc, and
measure cost and runtime per run.
**Owner:** Data Platform (+ GCP Dataproc for the Dataproc runs).
**Produces:** the deployed jobs, the `analytics.benchmark.results` table, and a Lakeview
dashboard over it.

This is the testing layer, packaged as a **Databricks Asset Bundle**:
`databricks bundle deploy` pushes the jobs and dashboard; `databricks bundle run` executes them.

> **Phase 5 — Benchmark Setup** (the BigQuery detailed billing export + scoped view, and the
> service-principal creation) is prerequisite plumbing, documented in
> **[prerequisites.md](prerequisites.md)**. Phases 6.1–6.2 below are the run and the measurement.

## 6.1 · Run benchmark jobs

Each PySpark file is **one Databricks job with one task**. The same file runs three ways:

| # | Where | Engine | How |
|---|---|---|---|
| 1 | Databricks | **Spark** (STANDARD) | `bundle run` with `engine=STANDARD`, `engine_tag=spark` |
| 2 | Databricks | **Photon** | `bundle run` with `engine=PHOTON`, `engine_tag=photon` |
| 3 | Dataproc | Spark | submitted on Dataproc, the same file |

Runs 1 and 2 use **identical, fixed hardware** (node types, worker count, DBR version — all
bundle variables), so the engine is the only variable, matched to the Dataproc cluster in #3.

### The Dataproc run

The Dataproc submit is issued using the **`gcp-dataproc-runner`** service account (its key is
read from the secret scope). For a fair, attributable comparison:

- **Match the hardware** — size the Dataproc cluster to the Databricks clusters (same machine
  types and worker count).
- **Label the cluster/job** with `project`, `engine=dataproc`, and `run_id=<dataproc job id>`
  so the run's VM cost is attributable in the billing view.
- **Set the per-job IAM policy** for the data-collector service principal after submitting each
  job — see [prerequisites.md §4](prerequisites.md#4-dataproc-per-job-access-the-submitters-extra-step).

## 6.2 · Measure & monitor

Every run lands one row in `analytics.benchmark.results` (see `sql/results_table.sql`), keyed
by `run_id`. Cost has two parts:

- **Databricks runs:** DBU $ (from `system.billing.usage`, keyed by `job_run_id`) **+** VM $
  (from the BigQuery billing view).
- **Dataproc runs:** runtime (from the Dataproc Jobs API) **+** VM $ (same billing view).

`run_id` is the join key on both cost sources: on Databricks it is injected as a VM label via
the `{{job.run_id}}` dynamic reference (equal to `usage_metadata.job_run_id`); on Dataproc it
is the Dataproc job id set as a label. Per-run cost is therefore unambiguous.

```mermaid
flowchart TB
    R["analytics.benchmark.results"]
    C1["collect_dbx<br/>DBU (system tables) + VM $ (BQ view)"]
    C2["collect_dataproc<br/>runtime (Dataproc API) + VM $ (BQ view)"]
    D["Lakeview dashboard"]
    C1 --> R
    C2 --> R
    R --> D
```

The **Lakeview** dashboard over `analytics.benchmark.results` shows per-job total cost as a
stacked bar (Databricks DBU + GCP VM) with the Dataproc bar beside it, plus runtime and
price-performance views. It deploys with the bundle (dashboard-as-code). Tune from there —
cluster size, data layout — and re-run; each iteration is a one-line change plus `bundle run`.

## Identities (run-as, separation of duties)

Five principals — two GCP service accounts and three Databricks service principals. People
only trigger jobs and view results; each Databricks SP reads only its own GCP key from the
secret scope.

| Principal | Type | Does | Access |
|---|---|---|---|
| `gcp-dataproc-runner` | GCP SA | submit the Dataproc job (invoked from a Databricks job) | `dataproc.jobs.create` on the cluster |
| `gcp-data-collector` | GCP SA | Dataproc runtimes + BigQuery costs | `dataproc.jobs.get` (per-job) + BigQuery view read |
| `bench-runner` | Databricks SP | runs the Photon/Spark jobs + triggers the Dataproc submit | read `customer_data_ro`, write `analytics.workloads` |
| `bench-collector` | Databricks SP | materializes the results table | write `analytics.benchmark`, read system tables, read the secret scope |
| `bench-analyst` | Databricks SP | builds the dashboard | read `analytics.benchmark` only |

Creating the principals, assigning the SPs to the workspace, the runner's
`allow-cluster-create` entitlement, enabling the system schemas, running the grants, and the
secret ACLs are all in **[prerequisites.md](prerequisites.md)**.

## Layout

```
databricks.yml            bundle: variables (engine, compute, collector config) + dev/prod
resources/
  sample_job.yml          the workload job (1 file → 1 task); retries, nodes, failure email, tags
  collectors.yml          the two cost collectors as on-demand jobs
src/
  sample_job.py           minimal, engine-agnostic pyspark workload
  collect_dbx.py          system tables (DBU) + BQ view (VM) → results
  collect_dataproc.py     Dataproc API (runtime) + BQ view (VM) → results
  bq_billing.py           shared: read VM cost per run_id from the scoped BQ view
sql/
  results_table.sql       DDL for analytics.benchmark.results
  grants.sql              schemas + least-privilege grants for the service principals
prerequisites.md          Phase 5 setup: BigQuery export/view, service principals, secrets
```

## How to run

Complete the Phase 5 setup first — **[prerequisites.md](prerequisites.md)** (BigQuery billing
export, scoped billing view, service principals + secrets, Dataproc per-job IAM). Then:

```bash
# 0) one-time: create the results table (sql/results_table.sql) and run grants (sql/grants.sql)

# 1) deploy, then run the two Databricks engines
databricks bundle deploy
databricks bundle run sample_job                                          # Photon (default)
databricks bundle run sample_job -- --var="engine=STANDARD" --var="engine_tag=spark"

# 2) submit the same file on Dataproc (dataproc-runner), then set the per-job IAM for the SP

# 3) after runs + billing export settle, collect costs
databricks bundle run collect_dbx
databricks bundle run collect_dataproc -- --job-name=<name> --run-ids=<id1,id2,...>
```

## Notes

- **Example values — replace before applying** (bundle variables and the identifiers in
  `prerequisites.md`).
- **Run the engines one at a time** on a given file so each run's window is clean (this matters
  only for the GCP VM-cost half; the DBU half is keyed by `job_run_id` regardless).
- The collectors need `google-cloud-bigquery` / `google-cloud-dataproc`, declared as job
  libraries in `resources/collectors.yml`.
