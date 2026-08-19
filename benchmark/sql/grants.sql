-- Least-privilege grants for the three test service principals.
-- Run this AS THE OWNER of the `analytics` catalog (the catalog_automation_sp from
-- data-access). Replace the placeholder principals with each SP's application id.
--
--   :runner    -> bench-runner    (runs the benchmark jobs)
--   :collector -> bench-collector (generates the cost results)
--   :analyst   -> bench-analyst   (reads results, builds dashboards)
--
-- The two GCP service accounts (dataproc-runner, data-collector) are not UC principals, so
-- they're not granted here — their access is GCP IAM + secret-scope reads (prerequisites.md):
-- bench-runner reads the dataproc-runner key, bench-collector reads the data-collector key.
-- SP creation, workspace assignment, the runner's allow-cluster-create entitlement, the
-- secret-scope READs, and enabling the system schemas are documented in prerequisites.md.

-- Two schemas: keep job outputs and cost results separate so runner/collector don't overlap.
CREATE SCHEMA IF NOT EXISTS analytics.workloads;   -- job outputs (runner writes, if jobs write)
CREATE SCHEMA IF NOT EXISTS analytics.benchmark;   -- cost results table (collector writes)

-- ---- bench-runner: read the source data, write job outputs ----
GRANT USE CATALOG ON CATALOG analytics TO `:runner`;
GRANT USE SCHEMA, CREATE, MODIFY, SELECT ON SCHEMA analytics.workloads TO `:runner`;
GRANT USE CATALOG ON CATALOG customer_data_ro TO `:runner`;
GRANT USE SCHEMA, SELECT ON SCHEMA customer_data_ro.raw TO `:runner`;

-- ---- bench-collector: write the results table, read the system tables ----
GRANT USE CATALOG ON CATALOG analytics TO `:collector`;
GRANT USE SCHEMA, CREATE, MODIFY, SELECT ON SCHEMA analytics.benchmark TO `:collector`;
GRANT USE CATALOG ON CATALOG system TO `:collector`;
GRANT USE SCHEMA, SELECT ON SCHEMA system.billing TO `:collector`;
GRANT USE SCHEMA, SELECT ON SCHEMA system.compute TO `:collector`;
GRANT USE SCHEMA, SELECT ON SCHEMA system.query   TO `:collector`;
GRANT USE SCHEMA, SELECT ON SCHEMA system.access  TO `:collector`;

-- ---- bench-analyst: read the results only (for dashboards) ----
GRANT USE CATALOG ON CATALOG analytics TO `:analyst`;
GRANT USE SCHEMA, SELECT ON SCHEMA analytics.benchmark TO `:analyst`;
