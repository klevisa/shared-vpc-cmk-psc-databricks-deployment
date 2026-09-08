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

# ---- Handoff from step 2.4 (workspace, PHASE 1) ----
variable "gcp_workspace_sa" {
  type        = string
  description = "From workspace output gcp_workspace_sa (db-<id>@prod-gcp-<region>, no serviceAccount: prefix)."
}
variable "workspace_id" {
  type        = string
  description = "From workspace output workspace_id — used in the resource-role IAM condition to scope the grant to this workspace."
}
