# -----------------------------------------------------------------------------
# READ-WRITE (managed) catalog over the analytics DATA bucket (created here).
# create bucket (analytics_bucket team) -> credential (uc_admin) -> read-write bucket IAM
# + VPC-SC ingress (perimeter team) -> read-write external location -> catalog with a
# managed storage_root on the analytics data bucket + schema.
# -----------------------------------------------------------------------------

# The analytics data bucket — created by the Data Platform team.
resource "google_storage_bucket" "analytics" {
  provider                    = google.analytics_bucket
  name                        = var.analytics_bucket
  project                     = var.analytics_bucket_project
  location                    = var.analytics_bucket_location
  uniform_bucket_level_access = true
}

resource "databricks_storage_credential" "rw" {
  provider = databricks.uc_admin
  name     = var.readwrite_storage_credential_name
  comment  = "Read-write access to the analytics data bucket"
  databricks_gcp_service_account {}

  # Ownership transfers to the governance group; isolate to this workspace. A metastore
  # admin can reassign ownership later if needed.
  owner          = var.governance_group
  isolation_mode = "ISOLATION_MODE_ISOLATED"

  depends_on = [databricks_grants.automation]
}

# GCS IAM — read-write, granted to the generated SA on the analytics data bucket.
# PoC time-box: both bindings self-expire at var.poc_expiry via a request.time IAM
# condition. The analytics bucket sets uniform_bucket_level_access = true (above), which
# GCS IAM conditions require.
resource "google_storage_bucket_iam_member" "rw_admin" {
  provider = google.analytics_bucket
  bucket   = google_storage_bucket.analytics.name
  # objectUser: create/get/list/delete/update on objects, WITHOUT object-level setIamPolicy
  # that objectAdmin also carries. The RW credential never needs to rewrite object ACLs.
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${databricks_storage_credential.rw.databricks_gcp_service_account[0].email}"
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC write grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

resource "google_storage_bucket_iam_member" "rw_lister" {
  provider = google.analytics_bucket
  bucket   = google_storage_bucket.analytics.name
  role     = "roles/storage.legacyBucketReader"
  member   = "serviceAccount:${databricks_storage_credential.rw.databricks_gcp_service_account[0].email}"
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC write grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# VPC-SC ingress — let the generated SA reach the analytics bucket over the Storage API
# (read + write methods).
resource "google_access_context_manager_service_perimeter_ingress_policy" "rw" {
  provider  = google.perimeter
  perimeter = var.perimeter_name
  title     = "databricks-catalog-rw-gcs"

  ingress_from {
    identities = ["serviceAccount:${databricks_storage_credential.rw.databricks_gcp_service_account[0].email}"]
    # Optional source-pinning: restrict entry to calls originating from Databricks'
    # own projects (control-plane + serverless-compute). Empty var = identity-only.
    dynamic "sources" {
      for_each = var.databricks_source_projects
      content {
        resource = sources.value
      }
    }
  }
  ingress_to {
    resources = var.readwrite_protected_resources
    operations {
      service_name = "storage.googleapis.com"
      # Object + multipart methods only — NOT "*", which would also admit bucket-IAM /
      # delete / update methods the objectUser grant doesn't need.
      method_selectors { method = "google.storage.objects.get" }
      method_selectors { method = "google.storage.objects.list" }
      method_selectors { method = "google.storage.objects.create" }
      method_selectors { method = "google.storage.objects.delete" }
      method_selectors { method = "google.storage.objects.update" }
      method_selectors { method = "google.storage.buckets.get" }
    }
  }
}

# Read-write external location — after bucket + IAM + ingress so validation passes.
resource "databricks_external_location" "rw" {
  provider        = databricks.uc_admin
  name            = var.readwrite_external_location_name
  url             = "gs://${google_storage_bucket.analytics.name}"
  credential_name = databricks_storage_credential.rw.name
  read_only       = false
  comment         = "Read-write external location over the analytics data bucket"
  owner           = var.governance_group
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  depends_on = [
    google_storage_bucket_iam_member.rw_admin,
    google_storage_bucket_iam_member.rw_lister,
    google_access_context_manager_service_perimeter_ingress_policy.rw,
  ]
}

# Managed catalog — storage_root on the analytics data bucket, so managed tables land there.
resource "databricks_catalog" "rw" {
  provider       = databricks.uc_admin
  name           = var.readwrite_catalog_name
  storage_root   = "gs://${google_storage_bucket.analytics.name}"
  comment        = "Read-write managed catalog; managed tables land in the analytics data bucket"
  owner          = var.governance_group
  isolation_mode = "ISOLATED"
  depends_on     = [databricks_external_location.rw]
}

resource "databricks_schema" "rw" {
  provider     = databricks.uc_admin
  catalog_name = databricks_catalog.rw.name
  name         = var.readwrite_schema_name
}
