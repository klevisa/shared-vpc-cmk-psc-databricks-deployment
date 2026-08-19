-- The single results table every collector writes to and the dashboard reads from.
-- One row per (job, platform, engine, run). Lives in the read-write "analytics" catalog.
CREATE TABLE IF NOT EXISTS analytics.benchmark.results (
  job_name        STRING,     -- logical job / pyspark file name
  platform        STRING,     -- databricks | dataproc
  engine          STRING,     -- photon | spark | dataproc
  run_id          STRING,     -- databricks job_run_id, OR the dataproc job id
  run_start       TIMESTAMP,
  run_end         TIMESTAMP,
  duration_s      DOUBLE,
  dbu             DOUBLE,      -- NULL for dataproc rows
  dbu_cost_usd    DOUBLE,      -- NULL for dataproc rows
  gcp_vm_cost_usd DOUBLE,      -- underlying VM cost from the BigQuery billing view
  total_cost_usd  DOUBLE,      -- dbu_cost_usd (if any) + gcp_vm_cost_usd
  source          STRING,      -- which collector wrote the row
  collected_at    TIMESTAMP
) USING DELTA;
