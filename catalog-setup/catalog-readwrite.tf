# -----------------------------------------------------------------------------
# READ-WRITE catalog over a separate scratch/output bucket.
# Storage credential (own generated SA) -> grant it read-write bucket IAM + a VPC-SC
# ingress rule (all Storage methods) -> read-write external location -> catalog with a
# managed storage_root on the scratch bucket (managed tables land there) + schema.
# -----------------------------------------------------------------------------

resource "databricks_storage_credential" "rw" {
  provider = databricks.workspace
  name     = var.readwrite_storage_credential_name
  comment  = "Read-write access to the PoC scratch bucket"
  databricks_gcp_service_account {}
}

# GCS IAM — read-write (object admin + bucket listing), granted to the generated SA.
resource "google_storage_bucket_iam_member" "rw_admin" {
  bucket = var.readwrite_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${databricks_storage_credential.rw.databricks_gcp_service_account[0].email}"
}

resource "google_storage_bucket_iam_member" "rw_lister" {
  bucket = var.readwrite_bucket
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${databricks_storage_credential.rw.databricks_gcp_service_account[0].email}"
}

# VPC-SC ingress — let the generated SA reach the scratch bucket over the Storage API
# (read + write methods).
resource "google_access_context_manager_service_perimeter_ingress_policy" "rw" {
  perimeter = var.perimeter_name
  title     = "databricks-catalog-rw-gcs"

  ingress_from {
    identities = ["serviceAccount:${databricks_storage_credential.rw.databricks_gcp_service_account[0].email}"]
  }
  ingress_to {
    resources = var.protected_resources
    operations {
      service_name = "storage.googleapis.com"
      method_selectors { method = "*" }
    }
  }
}

# Read-write external location — created after IAM + ingress so validation passes.
resource "databricks_external_location" "rw" {
  provider        = databricks.workspace
  name            = var.readwrite_external_location_name
  url             = "gs://${var.readwrite_bucket}"
  credential_name = databricks_storage_credential.rw.name
  read_only       = false
  comment         = "Read-write external location over the PoC scratch bucket"
  depends_on = [
    google_storage_bucket_iam_member.rw_admin,
    google_storage_bucket_iam_member.rw_lister,
    google_access_context_manager_service_perimeter_ingress_policy.rw,
  ]
}

# Managed catalog — storage_root points at the scratch bucket, so managed tables
# (CREATE TABLE / saveAsTable with no location) land there. Requires the external
# location above to cover the path.
resource "databricks_catalog" "rw" {
  provider     = databricks.workspace
  name         = var.readwrite_catalog_name
  storage_root = "gs://${var.readwrite_bucket}"
  comment      = "Read-write PoC catalog; managed tables land in the scratch bucket"
  depends_on   = [databricks_external_location.rw]
}

resource "databricks_schema" "rw" {
  provider     = databricks.workspace
  catalog_name = databricks_catalog.rw.name
  name         = var.readwrite_schema_name
}
