# Benchmark — Dataproc vs Photon (cost + runtime)

Runs the pre-agreed pyspark jobs three ways, collects **runtime and cost** for each run into
one Delta table, and plots them. Deployed as a **Databricks Asset Bundle** (no Terraform):
`databricks bundle deploy` pushes the jobs; `databricks bundle run` executes them.

## The three ways each pyspark file is run

Each pyspark file is **one job with one task**. The same file runs on:

| # | Where | Engine | How |
|---|---|---|---|
| 1 | Databricks | **Spark** (STANDARD) | `bundle run` with `engine=STANDARD`, `engine_tag=spark` |
| 2 | Databricks | **Photon** | `bundle run` with `engine=PHOTON`, `engine_tag=photon` |
| 3 | Dataproc | (Spark) | submitted on GCP by the customer, same file |

Runs 1 & 2 use **identical, fixed hardware** (node types, worker count, DBR version — all
bundle variables) so the engine is the only variable, matched to the Dataproc cluster in #3.

## Cost model — one table, many collectors

Everything lands in `analytics.benchmark.results` (see `sql/results_table.sql`), one row per
`(job, platform, engine, run)`. Cost has two parts:

- **Databricks runs:** DBU $ (from `system.billing.usage`, keyed by `job_run_id`) **+** VM $
  (from the BigQuery billing view).
- **Dataproc runs:** runtime (from the Dataproc Jobs API) **+** VM $ (same billing view).

The join key is **`run_id`**, present on both cost sources: on Databricks it's injected as a
VM label via the `{{job.run_id}}` dynamic reference (= `usage_metadata.job_run_id`); on
Dataproc it's the Dataproc job id the submitter puts in the label. So per-run cost is
unambiguous — no time-windowing.

```
                    analytics.benchmark.results
                    ▲            ▲                 ▲
   collect_dbx ─────┘   collect_dataproc ─────┘   (Lakeview dashboard reads)
   DBU (system tables)  runtime (Dataproc API)
   + VM $ (BQ view)     + VM $ (BQ view)
```

## Layout

```
databricks.yml            bundle: variables (engine, compute, collector config) + dev/prod
resources/
  sample_job.yml          the workload job (1 file -> 1 task); retries, nodes, failure email, tags
  collectors.yml          the two cost collectors as on-demand (unscheduled) jobs
src/
  sample_job.py           minimal, engine-agnostic pyspark workload
  collect_dbx.py          system tables (DBU) + BQ view (VM) -> results
  collect_dataproc.py     Dataproc API (runtime) + BQ view (VM) -> results
  bq_billing.py           shared: read VM cost per run_id from the scoped BQ view
sql/
  results_table.sql       DDL for analytics.benchmark.results
  grants.sql              schemas + least-privilege grants for the three test SPs
prerequisites.md          GCP-side setup + the three test service principals
```

## Identities (run-as, separation of duties)

Three Databricks service principals, created once as part of setup (no governance layer, no
cluster policies). Jobs run **as** these SPs; humans only trigger/view.

| SP | Runs as | Access |
|---|---|---|
| `bench-runner` | the workload jobs | read `customer_data_ro`, write `analytics.workloads` |
| `bench-collector` | the collectors | write `analytics.benchmark`, read system tables, READ the secret scope |
| `bench-analyst` | the dashboards | read `analytics.benchmark` only |

Set `runner_sp` / `collector_sp` in `databricks.yml` to the SPs' application ids after you
create them. Full setup — creation, workspace assignment, the runner's `allow-cluster-create`
entitlement, system-schema enablement, grants, secret ACL — is in **[`prerequisites.md`](prerequisites.md)**.

## How to run

Prereqs first — **[`prerequisites.md`](prerequisites.md)** (BigQuery export, scoped billing
view, GCP service account + secret, Dataproc per-job IAM, and the three test SPs). Then:

```bash
# 0) one-time: create the results table (sql/results_table.sql) and run grants (sql/grants.sql)

# 1) Spark baseline run
databricks bundle deploy
databricks bundle run sample_job                      # engine defaults to PHOTON...
databricks bundle run sample_job -- --var="engine=STANDARD" --var="engine_tag=spark"

# 2) (customer) submit the same file on Dataproc, then set the per-job IAM policy for the SP

# 3) after runs + billing export settle, collect costs
databricks bundle run collect_dbx
databricks bundle run collect_dataproc -- --job-name=<name> --run-ids=<id1,id2,...>
```

## Plotting (Lakeview) — next

A Lakeview dashboard over `analytics.benchmark.results`: **per-job total cost as a stacked
bar (Databricks DBU + GCP VM) with the Dataproc bar beside it**, plus runtime and
price-performance views. It'll deploy with the bundle (dashboard-as-code). Not built yet —
it's the last piece once the results-table shape is agreed.

## Notes

- **Values are illustrative** and not apply-tested. Adapt `databricks.yml` variables and the
  identifiers in `prerequisites.md`.
- **Run engines one at a time** on a given file so each run's window is clean (matters only
  for the GCP VM-cost half; the DBU half is keyed by `job_run_id` regardless).
- The collectors need `google-cloud-bigquery` / `google-cloud-dataproc` (declared as job
  libraries in `resources/collectors.yml`).
