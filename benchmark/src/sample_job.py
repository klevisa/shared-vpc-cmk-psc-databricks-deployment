"""Sample benchmark PySpark job.

Deliberately minimal and engine-agnostic — it runs identically on Photon, on the
Databricks Spark baseline, and on Dataproc, so the engine is the only variable. It does
a bit of real work (a shuffle + aggregation over a generated range) so the run is
measurable, and takes its size from a Spark conf so you can scale it without editing code.

Set the row count via the cluster Spark conf `spark.benchmark.rows` (default 100M).
"""
from pyspark.sql import SparkSession
from pyspark.sql import functions as F


def main() -> None:
    spark = SparkSession.builder.getOrCreate()

    rows = int(spark.conf.get("spark.benchmark.rows", "100000000"))

    df = spark.range(rows).withColumn("bucket", F.col("id") % F.lit(1000))
    agg = (
        df.groupBy("bucket")
        .agg(F.count(F.lit(1)).alias("cnt"), F.sum("id").alias("total"))
        .orderBy(F.desc("cnt"))
    )

    # Force full execution and emit a small, deterministic signal.
    top = agg.limit(20).collect()
    print(f"benchmark: rows={rows} buckets={len(top)} top_bucket={top[0]['bucket'] if top else None}")


if __name__ == "__main__":
    main()
