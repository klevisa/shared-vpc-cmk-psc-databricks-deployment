# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "SECURITY/KMS team's automation SA (same as step 2.3). Standing role: roles/cloudkms.admin on the SERVICE project. Runner needs iam.serviceAccountTokenCreator on it."
}
variable "google_project_name" {
  type        = string
  description = "SERVICE project id — where the CMEK key lives. Same value as step 2.3."
}
variable "google_region" {
  type    = string
  default = "us-central1"
}

# ---- PoC time-box ----
# RFC3339 UTC timestamp after which the workspace-SA MANAGED_SERVICES CMEK grant
# auto-expires, via a request.time IAM condition. Set it to the PoC end date. Backstops
# teardown; does not replace it.
variable "poc_expiry" {
  type        = string
  description = "RFC3339 UTC timestamp after which this config's PoC IAM grants auto-expire (request.time IAM condition), e.g. \"2026-12-31T00:00:00Z\"."
}

# ---- Handoff from step 2.3 (cmek) ----
variable "cmek_key_id" {
  type        = string
  description = "From cmek output cmek_key_id: the full KMS resource id (projects/<svc>/locations/<region>/keyRings/<kr>/cryptoKeys/<key>)."
}

# ---- Handoff from step 2.4 (workspace) ----
variable "gcp_workspace_sa" {
  type        = string
  description = "From workspace output gcp_workspace_sa (db-<id>@prod-gcp-<region>, no serviceAccount: prefix)."
}
