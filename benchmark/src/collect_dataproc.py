"""Dataproc-side cost collector (unscheduled — run on demand).

Given a job name, resolves its Dataproc run ids from the tracking table
(analytics.benchmark.dataproc_runs, populated by submit_dataproc) — or an explicit
--run-ids override — and writes platform='dataproc' rows to analytics.benchmark.results:
  - duration  from the Dataproc Jobs API (jobs.get -> status_history: RUNNING -> terminal).
              The SP holds ONLY dataproc.jobs.get, granted per-job via jobs.setIamPolicy.
  - VM   $    from the SAME scoped BigQuery billing view (Dataproc VMs labeled with the
              job id as run_id + platform=dataproc by the submitter).

Illustrative: adapt the config, install google-cloud-dataproc + google-cloud-bigquery on
the cluster (see resources/collectors.yml).
"""
import argparse
import datetime as dt

from google.cloud import dataproc_v1
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

import bq_billing


def _duration_seconds(job) -> float:
    """RUNNING -> terminal state, from the job's status history."""
    running = terminal = None
    history = list(job.status_history) + [job.status]
    for st in history:
        if st.state == dataproc_v1.JobStatus.State.RUNNING and running is None:
            running = st.state_start_time
        if st.state in (
            dataproc_v1.JobStatus.State.DONE,
            dataproc_v1.JobStatus.State.ERROR,
            dataproc_v1.JobStatus.State.CANCELLED,
        ):
            terminal = st.state_start_time
    if running and terminal:
        return (terminal - running).total_seconds()
    return float("nan")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--job-name", required=True)
    ap.add_argument("--run-ids", default=None, help="comma-separated Dataproc job ids (override; default reads --runs-table)")
    ap.add_argument("--runs-table", default="analytics.benchmark.dataproc_runs")
    ap.add_argument("--gcp-project", required=True)
    ap.add_argument("--dataproc-region", required=True)
    ap.add_argument("--results-table", default="analytics.benchmark.results")
    ap.add_argument("--bq-view", required=True)
    ap.add_argument("--secret-scope", default="benchmark")
    ap.add_argument("--secret-key", default="gcp_data_collector_key")
    args = ap.parse_args()

    spark = SparkSession.builder.getOrCreate()
    from pyspark.dbutils import DBUtils

    dbutils = DBUtils(spark)

    # Run ids: explicit override, else the ones submit_dataproc recorded for this job.
    if args.run_ids:
        run_ids = [r.strip() for r in args.run_ids.split(",") if r.strip()]
    else:
        run_ids = [
            row["run_id"]
            for row in spark.sql(
                f"SELECT run_id FROM {args.runs_table} WHERE job_name = '{args.job_name}'"
            ).collect()
        ]

    creds = bq_billing.gcp_credentials(dbutils, args.secret_scope, args.secret_key)

    # 1) Duration per run from the Dataproc Jobs API.
    jc = dataproc_v1.JobControllerClient(
        credentials=creds,
        client_options={"api_endpoint": f"{args.dataproc_region}-dataproc.googleapis.com:443"},
    )
    durations = []
    for rid in run_ids:
        job = jc.get_job(project_id=args.gcp_project, region=args.dataproc_region, job_id=rid)
        durations.append((rid, _duration_seconds(job)))

    # 2) VM cost per run from the scoped BigQuery billing view.
    vm = bq_billing.vm_cost_by_run(creds, args.bq_view, platform="dataproc")

    # 3) Shape to the results schema and MERGE by (run_id, platform).
    now = dt.datetime.utcnow()
    data = [
        (
            args.job_name, "dataproc", "dataproc", rid, dur,
            float(vm.get(rid, 0.0)), float(vm.get(rid, 0.0)),
        )
        for rid, dur in durations
    ]
    rows = (
        spark.createDataFrame(
            data,
            schema="job_name string, platform string, engine string, run_id string, "
            "duration_s double, gcp_vm_cost_usd double, total_cost_usd double",
        )
        .withColumn("source", F.lit("collect_dataproc"))
        .withColumn("collected_at", F.lit(now).cast("timestamp"))
    )
    rows.createOrReplaceTempView("dataproc_rows")

    spark.sql(
        f"""
        MERGE INTO {args.results_table} t
        USING dataproc_rows s
        ON t.run_id = s.run_id AND t.platform = s.platform
        WHEN MATCHED THEN UPDATE SET *
        WHEN NOT MATCHED THEN INSERT *
        """
    )
    print(f"collect_dataproc: upserted {rows.count()} dataproc run(s)")


if __name__ == "__main__":
    main()
