variable "google_service_account_email" {
  type        = string
  description = "SECURITY/KMS team's automation SA (impersonated). Standing role: roles/cloudkms.admin on the SERVICE project. Runner needs iam.serviceAccountTokenCreator on it."
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
variable "kms_keyring_name" { type = string }
variable "kms_key_name" { type = string }
