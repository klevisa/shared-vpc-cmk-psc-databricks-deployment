# -----------------------------------------------------------------------------
# Scoped privileges for the catalog AUTOMATION SA — least privilege, NOT admin.
# The account admin grants the automation SA exactly what it needs to build the
# catalogs: CREATE_CATALOG / CREATE_EXTERNAL_LOCATION / CREATE_STORAGE_CREDENTIAL on
# the metastore. It then owns whatever it creates.
#
# The metastore ADMIN is separate: the metastore's owner is an IdP-synced human
# governance group, set when the metastore is created (a prereq) — not managed here.
#
# NOTE: this grant must propagate before the uc_admin provider creates catalogs.
# Terraform orders it via depends_on; on a fresh grant you may occasionally need a
# second apply if propagation lags.
# -----------------------------------------------------------------------------

resource "databricks_grants" "automation" {
  provider  = databricks.accounts
  metastore = var.metastore_id
  grant {
    principal  = var.catalog_automation_sa
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
}
