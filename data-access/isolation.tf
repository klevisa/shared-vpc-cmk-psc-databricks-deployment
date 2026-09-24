# -----------------------------------------------------------------------------
# Workspace bindings for the ISOLATED securables (isolation_mode set on each object).
# With ISOLATED, a securable is only visible/usable in the workspaces it is bound to — so
# on a region-shared metastore other workspaces can't see or bind these catalogs. RO objects
# get a read-only binding; RW gets read-write. (Re-verify securable_type / binding_type
# enum values against your provider version in review.)
# -----------------------------------------------------------------------------

# ---- read-only trio ----
resource "databricks_workspace_binding" "ro_credential" {
  provider       = databricks.uc_admin
  workspace_id   = var.workspace_id
  securable_name = databricks_storage_credential.ro.name
  securable_type = "storage_credential"
  binding_type   = "BINDING_TYPE_READ_ONLY"
}
resource "databricks_workspace_binding" "ro_location" {
  provider       = databricks.uc_admin
  workspace_id   = var.workspace_id
  securable_name = databricks_external_location.ro.name
  securable_type = "external_location"
  binding_type   = "BINDING_TYPE_READ_ONLY"
}
resource "databricks_workspace_binding" "ro_catalog" {
  provider       = databricks.uc_admin
  workspace_id   = var.workspace_id
  securable_name = databricks_catalog.ro.name
  securable_type = "catalog"
  binding_type   = "BINDING_TYPE_READ_ONLY"
}

# ---- read-write trio ----
resource "databricks_workspace_binding" "rw_credential" {
  provider       = databricks.uc_admin
  workspace_id   = var.workspace_id
  securable_name = databricks_storage_credential.rw.name
  securable_type = "storage_credential"
  binding_type   = "BINDING_TYPE_READ_WRITE"
}
resource "databricks_workspace_binding" "rw_location" {
  provider       = databricks.uc_admin
  workspace_id   = var.workspace_id
  securable_name = databricks_external_location.rw.name
  securable_type = "external_location"
  binding_type   = "BINDING_TYPE_READ_WRITE"
}
resource "databricks_workspace_binding" "rw_catalog" {
  provider       = databricks.uc_admin
  workspace_id   = var.workspace_id
  securable_name = databricks_catalog.rw.name
  securable_type = "catalog"
  binding_type   = "BINDING_TYPE_READ_WRITE"
}
