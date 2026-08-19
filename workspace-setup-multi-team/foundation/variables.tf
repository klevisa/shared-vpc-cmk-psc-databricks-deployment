# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "FOUNDATION team's automation SA (impersonated). Org/folder standing: resourcemanager.projectCreator, billing.user, compute.xpnAdmin, resourcemanager.projectIamAdmin, serviceusage.serviceUsageAdmin. Runner needs iam.serviceAccountTokenCreator on it."
}
variable "google_region" {
  type    = string
  default = "us-central1"
}

# ---- Host project (ALREADY EXISTS) ----
variable "vpc_network_project_id" {
  type        = string
  description = "EXISTING host project id. This config does NOT create it — it enables it as a Shared VPC host and attaches the new service project."
}

# ---- Service project (CREATED here) ----
variable "service_project_id" {
  type        = string
  description = "Globally-unique project id to CREATE for the Databricks workspace's compute/storage + CMEK."
}
variable "service_project_name" {
  type        = string
  default     = "Databricks workspace service project"
  description = "Human-readable display name for the service project."
}

# Where the service project is created + how it's billed. Set org_id OR folder_id.
variable "org_id" {
  type        = string
  default     = ""
  description = "Organization id to create the service project under. Set this OR folder_id."
}
variable "folder_id" {
  type        = string
  default     = ""
  description = "Folder id to create the service project under. Set this OR org_id."
}
variable "billing_account" {
  type        = string
  description = "Billing account id to link to the service project (e.g. XXXXXX-XXXXXX-XXXXXX)."
}

# ---- APIs to enable (SERVICE project only; the host's are already enabled) ----
variable "service_project_apis" {
  type = list(string)
  default = [
    "compute.googleapis.com",
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "dns.googleapis.com",
  ]
}
