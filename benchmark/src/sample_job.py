"""Sample benchmark PySpark job.

Deliberately minimal and engine-agnostic — it runs identically on Photon, on the
Databricks Spark baseline, and on Dataproc, so the engine is the only variable. It does
a bit of real work (a shuffle + aggregation over a generated range) so the run is
measurable, and takes its size from a Spark conf so you can scale it without editing code.

Set the row count via the cluster Spark conf `spark.benchmark.rows` (default 100M).

Photon coverage (Approach A — plan-based, in-job): after the query runs, we walk its
executed physical plan and record what fraction of the operator nodes ran on Photon
(nodes named `Photon*`) vs fell back to the JVM Spark runtime. That number, plus the
list of non-Photon (fallback) operators, is written to the `--coverage-table` keyed by
`--run-id`, so `collect_dbx` can join it into the results table. On the Spark baseline
run this naturally comes out ~0% (no Photon operators); on Dataproc it is not measured.

  Caveat: this is a NODE-COUNT ratio, a structural proxy for the time-weighted
  "% of task time in Photon" that the Databricks Query Profile reports for SQL
  warehouses/serverless. It answers "how much of the plan Photonized, and what fell
  back," not an exact time fraction. For a faithful time-weighted number on job
  clusters, see "Approach B" in ../README.md / ../prerequisites.md: a bundled JVM
  QueryExecutionListener/SparkListener (pinned via `spark.extraListeners` through a
  cluster policy) that reads the executed plan + SQL metrics. That is heavier to set
  up (a JAR on a UC Volume) and is left as a documented upgrade path.
"""
import argparse
import datetime as dt

from pyspark.sql import SparkSession
from pyspark.sql import functions as F


def photon_coverage(df):
    """Fraction of executed-plan operator nodes that ran on Photon.

    Walks the executed physical plan via the JVM (py4j) and counts nodes whose name
    starts with "Photon" against the total operator count. Returns
    (coverage_pct, photon_nodes, total_nodes, sorted_fallback_op_names).

    Diagnostic only — wrapped so a benchmark run never fails because coverage couldn't
    be computed. AQE finalizes the plan during execution, so call this AFTER the query
    has run (e.g. after .collect()).
    """
    try:
        plan = df._jdf.queryExecution().executedPlan()
        skip = {"AdaptiveSparkPlan"}  # AQE wrapper, not a real operator
        photon = total = 0
        fallbacks = set()
        stack = [plan]
        while stack:
            node = stack.pop()
            name = node.nodeName()
            if name not in skip:
                total += 1
                if name.startswith("Photon"):
                    photon += 1
                else:
                    fallbacks.add(name)
            children = node.children()  # scala.collection.Seq[SparkPlan]
            for i in range(children.size()):
                stack.append(children.apply(i))
        pct = (100.0 * photon / total) if total else None
        return pct, photon, total, sorted(fallbacks)
    except Exception as exc:  # never break the benchmark for a diagnostic
        print(f"photon coverage: skipped ({exc})")
        return None, None, None, []


def main() -> None:
    ap = argparse.ArgumentParser()
    # Optional — when omitted (e.g. a standalone run) the job still runs, it just
    # prints coverage instead of recording it.
    ap.add_argument("--run-id", default=None, help="this run's id ({{job.run_id}}); key for the coverage row")
    ap.add_argument("--job-name", default="sample_job")
    ap.add_argument("--engine", default=None, help="engine tag (photon|spark) for the coverage row")
    ap.add_argument("--coverage-table", default=None, help="table to append the Photon-coverage row to")
    args = ap.parse_args()

    spark = SparkSession.builder.getOrCreate()

    rows = int(spark.conf.get("spark.benchmark.rows", "100000000"))

    df = spark.range(rows).withColumn("bucket", F.col("id") % F.lit(1000))
    agg = (
        df.groupBy("bucket")
        .agg(F.count(F.lit(1)).alias("cnt"), F.sum("id").alias("total"))
        .orderBy(F.desc("cnt"))
    )
    final_df = agg.limit(20)

    # Force full execution and emit a small, deterministic signal.
    top = final_df.collect()
    print(f"benchmark: rows={rows} buckets={len(top)} top_bucket={top[0]['bucket'] if top else None}")

    # Photon coverage over the plan that actually ran (see module docstring).
    pct, photon_nodes, total_nodes, fallbacks = photon_coverage(final_df)
    print(f"photon coverage: {pct}% ({photon_nodes}/{total_nodes} operator nodes); fallbacks={fallbacks}")

    if args.run_id and args.coverage_table:
        spark.createDataFrame(
            [(
                args.run_id, args.job_name, args.engine,
                pct, photon_nodes, total_nodes, ",".join(fallbacks),
                dt.datetime.utcnow(),
            )],
            schema="run_id string, job_name string, engine string, "
            "photon_coverage_pct double, photon_ops int, total_ops int, "
            "fallback_ops string, measured_at timestamp",
        ).write.mode("append").saveAsTable(args.coverage_table)


if __name__ == "__main__":
    main()
