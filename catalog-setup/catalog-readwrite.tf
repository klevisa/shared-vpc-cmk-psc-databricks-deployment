# -----------------------------------------------------------------------------
# READ-WRITE catalog over the PoC DATA bucket (created here).
# create bucket (poc_bucket team) -> credential (uc_admin) -> read-write bucket IAM +
# VPC-SC ingress (perimeter team) -> read-write external location -> catalog with a
# managed storage_root on the PoC data bucket + schema.
# -----------------------------------------------------------------------------

# The PoC data bucket — created by the Data Platform team.
resource "google_storage_bucket" "poc" {
  provider                    = google.poc_bucket
  name                        = var.poc_bucket
  project                     = var.poc_bucket_project
  location                    = var.poc_bucket_location
  uniform_bucket_level_access = true
}

resource "databricks_storage_credential" "rw" {
  provider = databricks.uc_admin
  name     = var.readwrite_storage_credential_name
  comment  = "Read-write access to the PoC data bucket"
  databricks_gcp_service_account {}

  depends_on = [databricks_grants.automation]
}

# GCS IAM — read-write, granted to the generated SA on the PoC data bucket.
resource "google_storage_bucket_iam_member" "rw_admin" {
  provider = google.poc_bucket
  bucket   = google_storage_bucket.poc.name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${databricks_storage_credential.rw.databricks_gcp_service_account[0].email}"
}

resource "google_storage_bucket_iam_member" "rw_lister" {
  provider = google.poc_bucket
  bucket   = google_storage_bucket.poc.name
  role     = "roles/storage.legacyBucketReader"
  member   = "serviceAccount:${databricks_storage_credential.rw.databricks_gcp_service_account[0].email}"
}

# VPC-SC ingress — let the generated SA reach the PoC bucket over the Storage API
# (read + write methods).
resource "google_access_context_manager_service_perimeter_ingress_policy" "rw" {
  provider  = google.perimeter
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

# Read-write external location — after bucket + IAM + ingress so validation passes.
resource "databricks_external_location" "rw" {
  provider        = databricks.uc_admin
  name            = var.readwrite_external_location_name
  url             = "gs://${google_storage_bucket.poc.name}"
  credential_name = databricks_storage_credential.rw.name
  read_only       = false
  comment         = "Read-write external location over the PoC data bucket"
  depends_on = [
    google_storage_bucket_iam_member.rw_admin,
    google_storage_bucket_iam_member.rw_lister,
    google_access_context_manager_service_perimeter_ingress_policy.rw,
  ]
}

# Managed catalog — storage_root on the PoC data bucket, so managed tables land there.
resource "databricks_catalog" "rw" {
  provider     = databricks.uc_admin
  name         = var.readwrite_catalog_name
  storage_root = "gs://${google_storage_bucket.poc.name}"
  comment      = "Read-write PoC catalog; managed tables land in the PoC data bucket"
  depends_on   = [databricks_external_location.rw]
}

resource "databricks_schema" "rw" {
  provider     = databricks.uc_admin
  catalog_name = databricks_catalog.rw.name
  name         = var.readwrite_schema_name
}
