# -----------------------------------------------------------------------------
# Airflow (Composer) orchestration + the one-time STS copy (prerequisites.md §4).
# Composer creates/labels the ephemeral Dataproc benchmark cluster, reads the source,
# writes poc_bucket, and drives an STS copy source -> poc_bucket. All grants scoped +
# time-boxed; custom roles instead of the broad predefined ones.
# -----------------------------------------------------------------------------

# poc_bucket project number → the Google-managed STS service agent email.
data "google_project" "poc" {
  provider   = google.poc_bucket
  project_id = var.poc_bucket_project
}

locals {
  sts_agent = "serviceAccount:project-${data.google_project.poc.number}@storage-transfer-service.iam.gserviceaccount.com"
  composer  = "serviceAccount:${var.composer_sa}"
}

# ---- Custom Dataproc role (not roles/dataproc.editor) ----
resource "google_project_iam_custom_role" "dataproc_bench" {
  provider    = google.service_project
  project     = var.gcp_project
  role_id     = "benchmarkDataproc"
  title       = "Benchmark Dataproc operator"
  description = "Create/observe/label the ephemeral benchmark Dataproc cluster; read job status."
  permissions = [
    "dataproc.clusters.create",
    "dataproc.clusters.get",
    "dataproc.clusters.delete",
    "dataproc.clusters.setLabels",
    "dataproc.jobs.get",
  ]
}

resource "google_project_iam_member" "composer_dataproc" {
  provider = google.service_project
  project  = var.gcp_project
  role     = google_project_iam_custom_role.dataproc_bench.id
  member   = local.composer
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# ---- Custom STS operator role (not roles/storagetransfer.admin) ----
resource "google_project_iam_custom_role" "sts_bench" {
  provider    = google.poc_bucket
  project     = var.poc_bucket_project
  role_id     = "benchmarkStorageTransfer"
  title       = "Benchmark Storage Transfer operator"
  description = "Create/run/observe the one-time source -> poc_bucket transfer."
  permissions = [
    "storagetransfer.jobs.create",
    "storagetransfer.jobs.get",
    "storagetransfer.jobs.run",
    "storagetransfer.operations.get",
    "storagetransfer.operations.list",
  ]
}

resource "google_project_iam_member" "composer_sts" {
  provider = google.poc_bucket
  project  = var.poc_bucket_project
  role     = google_project_iam_custom_role.sts_bench.id
  member   = local.composer
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# ---- Source (Mail) bucket: read-only, prefix-scoped, for Composer + the STS agent ----
# NOTE: prefix-scoped IAM conditions require UNIFORM BUCKET-LEVEL ACCESS on the source
# bucket. Confirm it's enabled, or drop the startsWith() clause.
locals {
  source_read_condition = "resource.name.startsWith(\"projects/_/buckets/${var.source_bucket}/objects/${var.source_object_prefix}\") && request.time < timestamp(\"${var.poc_expiry}\")"
  source_readers        = toset([local.composer, local.sts_agent])
}

resource "google_storage_bucket_iam_member" "source_readers" {
  provider = google.source_bucket
  for_each = local.source_readers
  bucket   = var.source_bucket
  role     = "roles/storage.objectViewer"
  member   = each.value
  condition {
    title       = "prefix-scope-and-poc-expiry"
    description = "Read only under the input prefix, and only until the PoC end date."
    expression  = local.source_read_condition
  }
}

# Optional: if the source bucket uses a customer-managed key, let the STS agent decrypt.
resource "google_kms_crypto_key_iam_member" "sts_source_decrypt" {
  count         = var.source_cmek_key == "" ? 0 : 1
  provider      = google.source_bucket
  crypto_key_id = var.source_cmek_key
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = local.sts_agent
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# ---- Copy-target poc_bucket: created here, written by Composer + the STS agent ----
resource "google_storage_bucket" "poc" {
  provider                    = google.poc_bucket
  project                     = var.poc_bucket_project
  name                        = var.poc_bucket_name
  location                    = var.poc_bucket_location
  uniform_bucket_level_access = true
  force_destroy               = true # copied input; safe to delete at teardown
}

# objectUser (not objectAdmin): object create/get/list/delete/update without object-IAM.
resource "google_storage_bucket_iam_member" "poc_writers" {
  provider = google.poc_bucket
  for_each = toset([local.composer, local.sts_agent])
  bucket   = google_storage_bucket.poc.name
  role     = "roles/storage.objectUser"
  member   = each.value
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# ---- VPC-SC: admit STS across the perimeter (source <-> poc_bucket) ----
# ONLY needed if the source bucket sits inside a VPC-SC perimeter and STS is the copy path.
# If the source isn't perimeter-protected, remove this rule.
resource "google_access_context_manager_service_perimeter_ingress_policy" "sts" {
  provider  = google.perimeter
  perimeter = var.perimeter_name
  title     = "benchmark-sts-copy"

  ingress_from {
    identities = [local.sts_agent]
  }
  ingress_to {
    resources = var.sts_protected_resources
    operations {
      service_name = "storage.googleapis.com"
      method_selectors { method = "google.storage.objects.get" }
      method_selectors { method = "google.storage.objects.list" }
      method_selectors { method = "google.storage.objects.create" }
    }
  }
}
