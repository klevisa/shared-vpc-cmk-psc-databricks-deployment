-- Schemas: job outputs (runner writes) vs cost results (collector writes) — kept separate so
-- the two SPs never share a write surface. Run this before sql/grants.sql.
CREATE SCHEMA IF NOT EXISTS analytics.workloads;
CREATE SCHEMA IF NOT EXISTS analytics.benchmark;

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

-- Run tracking so collection is automatic: submit_dataproc (bench-runner) appends the run_id
-- it mints; collect_dataproc (bench-collector) reads pending run_ids from here — no manual
-- --run-ids to pass. Lives in analytics.benchmark, which the collector already owns.
CREATE TABLE IF NOT EXISTS analytics.benchmark.dataproc_runs (
  run_id       STRING,
  job_name     STRING,
  engine       STRING,     -- always 'dataproc'
  submitted_at TIMESTAMP
) USING DELTA;
