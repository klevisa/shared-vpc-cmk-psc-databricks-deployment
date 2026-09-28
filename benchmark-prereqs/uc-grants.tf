# -----------------------------------------------------------------------------
# Unity Catalog grants for the three benchmark SPs — ported from sql/grants.sql so they
# live in state (drift detection + `terraform destroy`) instead of a hand-run script.
# Uses databricks_grant (SINGULAR = additive per principal), so these do NOT clobber other
# grants on the shared catalogs. Catalog/schema names match the data-access phase.
#
# The uc_admin provider must be a METASTORE ADMIN (or the owners of analytics /
# source_data_ro and able to grant on system).
# -----------------------------------------------------------------------------

# ---- bench-runner: read source, write job outputs ----
resource "databricks_grant" "runner_analytics_cat" {
  provider   = databricks.uc_admin
  catalog    = "analytics"
  principal  = var.runner_sp
  privileges = ["USE_CATALOG"]
}
resource "databricks_grant" "runner_workloads" {
  provider   = databricks.uc_admin
  schema     = "analytics.workloads"
  principal  = var.runner_sp
  privileges = ["USE_SCHEMA", "CREATE", "MODIFY", "SELECT"]
}
resource "databricks_grant" "runner_source_cat" {
  provider   = databricks.uc_admin
  catalog    = "source_data_ro"
  principal  = var.runner_sp
  privileges = ["USE_CATALOG"]
}
resource "databricks_grant" "runner_source_raw" {
  provider   = databricks.uc_admin
  schema     = "source_data_ro.raw"
  principal  = var.runner_sp
  privileges = ["USE_SCHEMA", "SELECT"]
}
# Append-only Photon coverage: USE_SCHEMA on the schema, MODIFY on the one table (no SELECT).
resource "databricks_grant" "runner_benchmark_schema" {
  provider   = databricks.uc_admin
  schema     = "analytics.benchmark"
  principal  = var.runner_sp
  privileges = ["USE_SCHEMA"]
}
resource "databricks_grant" "runner_coverage_table" {
  provider   = databricks.uc_admin
  table      = "analytics.benchmark.photon_coverage"
  principal  = var.runner_sp
  privileges = ["MODIFY"]
}

# ---- bench-collector: write results, read system tables ----
resource "databricks_grant" "collector_analytics_cat" {
  provider   = databricks.uc_admin
  catalog    = "analytics"
  principal  = var.collector_sp
  privileges = ["USE_CATALOG"]
}
resource "databricks_grant" "collector_benchmark" {
  provider   = databricks.uc_admin
  schema     = "analytics.benchmark"
  principal  = var.collector_sp
  privileges = ["USE_SCHEMA", "CREATE", "MODIFY", "SELECT"]
}
resource "databricks_grant" "collector_system_cat" {
  provider   = databricks.uc_admin
  catalog    = "system"
  principal  = var.collector_sp
  privileges = ["USE_CATALOG"]
}
resource "databricks_grant" "collector_system_billing" {
  provider   = databricks.uc_admin
  schema     = "system.billing"
  principal  = var.collector_sp
  privileges = ["USE_SCHEMA", "SELECT"]
}
resource "databricks_grant" "collector_system_lakeflow" {
  provider   = databricks.uc_admin
  schema     = "system.lakeflow"
  principal  = var.collector_sp
  privileges = ["USE_SCHEMA", "SELECT"]
}

# ---- bench-analyst: read results only ----
resource "databricks_grant" "analyst_analytics_cat" {
  provider   = databricks.uc_admin
  catalog    = "analytics"
  principal  = var.analyst_sp
  privileges = ["USE_CATALOG"]
}
resource "databricks_grant" "analyst_benchmark" {
  provider   = databricks.uc_admin
  schema     = "analytics.benchmark"
  principal  = var.analyst_sp
  privileges = ["USE_SCHEMA", "SELECT"]
}
