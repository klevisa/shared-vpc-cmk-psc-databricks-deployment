-- Least-privilege grants for the three test service principals.
-- Run this AS THE OWNER of the `analytics` catalog (the catalog_automation_sp from
-- data-access). Replace the placeholder principals with each SP's application id.
--
--   :runner    -> bench-runner    (runs the benchmark jobs)
--   :collector -> bench-collector (generates the cost results)
--   :analyst   -> bench-analyst   (reads results, builds dashboards)
--
-- The collector's GCP access is keyless — the collector SA is attached to its job cluster
-- and the code uses ADC (prerequisites.md §3). No GCP SA keys, no secret scopes. Dataproc is
-- observed by Airflow (it submits/labels the jobs and captures runtime); nothing here submits
-- to Dataproc. SP creation, workspace assignment, the runner's allow-cluster-create
-- entitlement, and enabling the system schemas are documented in prerequisites.md.

-- Schemas + tables are created by sql/results_table.sql — run it BEFORE this.

-- ---- bench-runner: read the source data, write job outputs ----
GRANT USE CATALOG ON CATALOG analytics TO `:runner`;
GRANT USE SCHEMA, CREATE, MODIFY, SELECT ON SCHEMA analytics.workloads TO `:runner`;
GRANT USE CATALOG ON CATALOG source_data_ro TO `:runner`;
GRANT USE SCHEMA, SELECT ON SCHEMA source_data_ro.raw TO `:runner`;
-- sample_job (runner) APPENDS its per-run Photon coverage. MODIFY only (UC has no INSERT-only
-- privilege), no SELECT, TABLE-level — so it can't touch the results table or the rest of the
-- collector's schema.
GRANT USE SCHEMA ON SCHEMA analytics.benchmark TO `:runner`;
GRANT MODIFY ON TABLE analytics.benchmark.photon_coverage TO `:runner`;

-- ---- bench-collector: write the results table, read the system tables ----
GRANT USE CATALOG ON CATALOG analytics TO `:collector`;
GRANT USE SCHEMA, CREATE, MODIFY, SELECT ON SCHEMA analytics.benchmark TO `:collector`;
-- Least privilege: the collector only needs billing (DBU + prices) and lakeflow (run times).
-- The other production system schemas (access/compute/query/data_classification/tags/storage)
-- are enabled at the metastore but their access is a separate, governance-owned concern.
GRANT USE CATALOG ON CATALOG system TO `:collector`;
GRANT USE SCHEMA, SELECT ON SCHEMA system.billing  TO `:collector`;
GRANT USE SCHEMA, SELECT ON SCHEMA system.lakeflow TO `:collector`;

-- ---- bench-analyst: read the results only (for dashboards) ----
GRANT USE CATALOG ON CATALOG analytics TO `:analyst`;
GRANT USE SCHEMA, SELECT ON SCHEMA analytics.benchmark TO `:analyst`;
