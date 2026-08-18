# -----------------------------------------------------------------------------
# Metastore admin, created FROM the account admin.
# The account admin creates a regional metastore-admin GROUP, adds the specified SA
# to it, and grants the group metastore-level CREATE privileges. That group (with the
# SA in it) is the metastore admin that then creates the catalogs below.
#
# NOTE: the granted privileges must propagate before the uc_admin provider can create
# catalogs. Terraform orders this via depends_on; on a fresh grant you may occasionally
# need a second apply if propagation lags.
# -----------------------------------------------------------------------------

resource "databricks_group" "metastore_admins" {
  provider     = databricks.accounts
  display_name = var.metastore_admin_group_name
}

# The specified SA must already be registered as a Databricks user (its GSA email) to
# authenticate — reference it read-only and add it to the group.
data "databricks_user" "admin_sa" {
  provider  = databricks.accounts
  user_name = var.metastore_admin_sa
}

resource "databricks_group_member" "admin_sa" {
  provider  = databricks.accounts
  group_id  = databricks_group.metastore_admins.id
  member_id = data.databricks_user.admin_sa.id
}

resource "databricks_grants" "metastore" {
  provider  = databricks.accounts
  metastore = var.metastore_id
  grant {
    principal  = databricks_group.metastore_admins.display_name
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
}
