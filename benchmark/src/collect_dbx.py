"""Databricks-side cost collector (unscheduled — run on demand after runs settle).

Combines the two Databricks-run cost halves and writes them to analytics.benchmark.results:
  - DBU + $  from system tables, keyed by usage_metadata.job_run_id (populated for JOB
             compute), joined to system.billing.list_prices for USD.
  - VM   $   from the scoped BigQuery billing view, keyed by the run_id VM label
             (= the same job_run_id, injected via {{job.run_id}} custom_tag).
Join on run_id -> per-run total cost, no time-windowing needed.

Illustrative: adapt the config, and install google-cloud-bigquery on the cluster
(see resources/collectors.yml). Run AFTER billing export + label propagation settle.
"""
import argparse
import datetime as dt

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

import bq_billing


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project-tag", default="dataproc-vs-photon")
    ap.add_argument("--results-table", default="analytics.benchmark.results")
    ap.add_argument("--bq-view", required=True, help="project.dataset.view of the scoped billing view")
    ap.add_argument("--secret-scope", default="benchmark")
    ap.add_argument("--secret-key", default="gcp_data_collector_key")
    args = ap.parse_args()

    spark = SparkSession.builder.getOrCreate()
    from pyspark.dbutils import DBUtils  # available on Databricks compute

    dbutils = DBUtils(spark)

    # 1) DBU cost per run from system tables (job_run_id is populated for job compute).
    dbu = spark.sql(
        f"""
        SELECT
          u.usage_metadata.job_run_id                         AS run_id,
          MAX(u.usage_metadata.job_name)                      AS job_name,
          MAX(u.custom_tags['engine'])                        AS engine,
          SUM(u.usage_quantity)                               AS dbu,
          SUM(u.usage_quantity * CAST(p.pricing.default AS DOUBLE)) AS dbu_cost_usd,
          MIN(u.usage_start_time)                             AS run_start,
          MAX(u.usage_end_time)                               AS run_end
        FROM system.billing.usage u
        LEFT JOIN system.billing.list_prices p
          ON  u.sku_name = p.sku_name AND u.cloud = p.cloud
          AND u.usage_start_time >= p.price_start_time
          AND (p.price_end_time IS NULL OR u.usage_start_time < p.price_end_time)
        WHERE u.usage_unit = 'DBU'
          AND u.custom_tags['project'] = '{args.project_tag}'
          AND u.usage_metadata.job_run_id IS NOT NULL
        GROUP BY u.usage_metadata.job_run_id
        """
    )

    # 2) VM cost per run from the scoped BigQuery billing view.
    creds = bq_billing.gcp_credentials(dbutils, args.secret_scope, args.secret_key)
    vm = bq_billing.vm_cost_by_run(creds, args.bq_view, platform="databricks")
    vm_sdf = spark.createDataFrame(
        [(k, float(v)) for k, v in vm.items()], schema="run_id string, gcp_vm_cost_usd double"
    )

    # 3) Join, shape to the results schema, MERGE by (run_id, platform).
    now = dt.datetime.utcnow()
    rows = (
        dbu.join(vm_sdf, "run_id", "left")
        .withColumn("platform", F.lit("databricks"))
        .withColumn("duration_s", F.col("run_end").cast("double") - F.col("run_start").cast("double"))
        .withColumn("gcp_vm_cost_usd", F.coalesce(F.col("gcp_vm_cost_usd"), F.lit(0.0)))
        .withColumn("total_cost_usd", F.coalesce(F.col("dbu_cost_usd"), F.lit(0.0)) + F.col("gcp_vm_cost_usd"))
        .withColumn("source", F.lit("collect_dbx"))
        .withColumn("collected_at", F.lit(now).cast("timestamp"))
    )
    rows.createOrReplaceTempView("dbx_rows")

    spark.sql(
        f"""
        MERGE INTO {args.results_table} t
        USING dbx_rows s
        ON t.run_id = s.run_id AND t.platform = s.platform
        WHEN MATCHED THEN UPDATE SET *
        WHEN NOT MATCHED THEN INSERT *
        """
    )
    print(f"collect_dbx: upserted {rows.count()} databricks run(s)")


if __name__ == "__main__":
    main()
