# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "CLOUD IAM team's automation SA (impersonated). Standing roles on the SERVICE project: roles/iam.roleAdmin (create custom roles) + roles/resourcemanager.projectIamAdmin (grant them). Runner needs iam.serviceAccountTokenCreator on it."
}
variable "google_project_name" {
  type        = string
  description = "SERVICE project id — where the workspace's compute/storage land. From step 2.1 service_project_id."
}
variable "google_region" {
  type    = string
  default = "us-central1"
}

# ---- PoC time-box ----
# RFC3339 UTC timestamp after which this config's PoC IAM grants auto-expire, via a
# request.time IAM condition. Set it to the PoC end date. This is the security-review
# time-boxing backstop — it does NOT replace teardown, it ensures the grant lapses even
# if teardown slips. (Not applied to the read-only creator roles/SA — those are stripped
# outright right after finalize; see workspace-setup/creator-teardown/.)
variable "poc_expiry" {
  type        = string
  description = "RFC3339 UTC timestamp after which this config's PoC IAM grants auto-expire (request.time IAM condition), e.g. \"2026-12-31T00:00:00Z\"."
}

# ---- Handoff from step 2.4 (workspace, PHASE 1) ----
variable "gcp_workspace_sa" {
  type        = string
  description = "From workspace output gcp_workspace_sa (db-<id>@prod-gcp-<region>, no serviceAccount: prefix)."
}
variable "workspace_id" {
  type        = string
  description = "From workspace output workspace_id — used in the resource-role IAM condition to scope the grant to this workspace."
}

# Compute/node SA the workspace SA sets as the VM identity; actAs granted on this SA only.
# Default = service project's GCE default SA (<number>-compute@developer.gserviceaccount.com).
variable "compute_sa_email" {
  type        = string
  description = "Compute/node SA email the workspace SA sets as the cluster VM identity (actAs granted on this SA only). No serviceAccount: prefix."
}
