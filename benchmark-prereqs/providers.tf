# Benchmark prerequisites — the grants that used to be manual gcloud/console steps
# (prerequisites.md §3-5), now in Terraform so they carry poc_expiry, are torn down by
# `terraform destroy`, and show up in the least-privilege identity map.
#
# One config, several aliased providers — each impersonates the team SA that owns the
# target resource (least privilege holds even though it's one config). Each runner needs
# roles/iam.serviceAccountTokenCreator on the SA it impersonates.
#
# GCP:
#   service_project : owns the service/Dataproc project — creates the collector SA + the
#                     custom Dataproc role and grants Composer the Dataproc role.
#   source_bucket   : owns the existing source (Mail) bucket — grants read on it.
#   poc_bucket      : owns the copy-target project — creates poc_bucket and grants write.
#   billing         : owns the billing project + authorized view — grants the collector BQ read.
#   perimeter       : Cloud/Network Security — adds the STS VPC-SC ingress rule.
# Databricks:
#   uc_admin        : a METASTORE ADMIN SP (OAuth M2M) — applies the SP Unity Catalog grants
#                     (ported from sql/grants.sql). Must be able to grant on analytics,
#                     source_data_ro and the system catalog.

provider "google" {
  alias                       = "service_project"
  project                     = var.gcp_project
  impersonate_service_account = var.service_project_admin_sa
}

provider "google" {
  alias                       = "source_bucket"
  project                     = var.source_bucket_project
  impersonate_service_account = var.source_bucket_sa
}

provider "google" {
  alias                       = "poc_bucket"
  project                     = var.poc_bucket_project
  impersonate_service_account = var.poc_bucket_sa
}

provider "google" {
  alias                       = "billing"
  project                     = var.billing_project
  impersonate_service_account = var.billing_sa
}

provider "google" {
  alias                       = "perimeter"
  project                     = var.poc_bucket_project # quota/context only
  impersonate_service_account = var.perimeter_sa
}

provider "databricks" {
  alias         = "uc_admin"
  host          = var.workspace_url
  client_id     = var.uc_grantor_sp # a metastore-admin SP (OAuth M2M client_id)
  client_secret = var.uc_grantor_client_secret
}
