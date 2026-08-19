# -----------------------------------------------------------------------------
# READ-ONLY catalog over the customer's EXISTING data bucket.
# credential (uc_admin) -> read-only bucket IAM (data_bucket team) + VPC-SC ingress
# scoped to read methods (perimeter team) -> read-only external location -> catalog +
# schema (namespace only; external tables registered here later).
# -----------------------------------------------------------------------------

resource "databricks_storage_credential" "ro" {
  provider = databricks.uc_admin
  name     = var.readonly_storage_credential_name
  comment  = "Read-only access to the existing data bucket"
  databricks_gcp_service_account {}

  # created only once the automation SA holds the scoped CREATE privileges
  depends_on = [databricks_grants.automation]
}

# GCS IAM — read-only, granted by the data-bucket owner to the generated SA.
resource "google_storage_bucket_iam_member" "ro_viewer" {
  provider = google.data_bucket
  bucket   = var.readonly_bucket
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${databricks_storage_credential.ro.databricks_gcp_service_account[0].email}"
}

resource "google_storage_bucket_iam_member" "ro_lister" {
  provider = google.data_bucket
  bucket   = var.readonly_bucket
  role     = "roles/storage.legacyBucketReader"
  member   = "serviceAccount:${databricks_storage_credential.ro.databricks_gcp_service_account[0].email}"
}

# VPC-SC ingress — let the generated SA reach the bucket over the Storage API,
# scoped to read methods (a fourth read-only guard).
resource "google_access_context_manager_service_perimeter_ingress_policy" "ro" {
  provider  = google.perimeter
  perimeter = var.perimeter_name
  title     = "databricks-catalog-ro-gcs"

  ingress_from {
    identities = ["serviceAccount:${databricks_storage_credential.ro.databricks_gcp_service_account[0].email}"]
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
    resources = var.protected_resources
    operations {
      service_name = "storage.googleapis.com"
      method_selectors { method = "google.storage.objects.get" }
      method_selectors { method = "google.storage.objects.list" }
    }
  }
}

# Read-only external location — after IAM + ingress so validation passes.
resource "databricks_external_location" "ro" {
  provider        = databricks.uc_admin
  name            = var.readonly_external_location_name
  url             = "gs://${var.readonly_bucket}"
  credential_name = databricks_storage_credential.ro.name
  read_only       = true
  comment         = "Read-only external location over the existing data bucket"
  depends_on = [
    google_storage_bucket_iam_member.ro_viewer,
    google_storage_bucket_iam_member.ro_lister,
    google_access_context_manager_service_perimeter_ingress_policy.ro,
  ]
}

# Namespace only — no managed storage_root (read-only). External tables added later.
resource "databricks_catalog" "ro" {
  provider = databricks.uc_admin
  name     = var.readonly_catalog_name
  comment  = "Read-only catalog over the customer data bucket; external tables added later"
}

resource "databricks_schema" "ro" {
  provider     = databricks.uc_admin
  catalog_name = databricks_catalog.ro.name
  name         = var.readonly_schema_name
}
