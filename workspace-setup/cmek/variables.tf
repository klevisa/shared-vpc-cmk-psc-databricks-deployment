variable "google_service_account_email" {
  type        = string
  description = "SECURITY/KMS team's automation SA (impersonated). Least privilege: grant roles/cloudkms.admin on the KEYRING resource (after a project-level cloudkms.keyRings.create custom role bootstraps it), not project-wide — this config only touches the one keyring. Runner needs iam.serviceAccountTokenCreator on it."
}
variable "google_project_name" {
  type        = string
  description = "SERVICE project id — where the CMEK key lives (its service agents encrypt with it)."
}
variable "google_service_project_number" {
  type        = string
  description = "SERVICE project NUMBER — for the compute-system (VM disks) and gs-project-accounts (GCS) agent emails."
}
variable "google_region" {
  type    = string
  default = "us-central1"
}

# ---- PoC time-box ----
# RFC3339 UTC timestamp after which the CMEK STORAGE-agent grants auto-expire, via a
# request.time IAM condition. Set it to the PoC end date. Backstops teardown; does not
# replace it.
variable "poc_expiry" {
  type        = string
  description = "RFC3339 UTC timestamp after which this config's PoC IAM grants auto-expire (request.time IAM condition), e.g. \"2026-12-31T00:00:00Z\"."
}

variable "kms_keyring_name" { type = string }
variable "kms_key_name" { type = string }
