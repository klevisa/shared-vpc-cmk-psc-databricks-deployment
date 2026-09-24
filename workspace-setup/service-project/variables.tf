# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "FOUNDATION team's automation SA (impersonated). Least-privilege standing roles: projectCreator + billing.user + compute.xpnAdmin at FOLDER scope (a dedicated PoC folder), and roleAdmin + projectIamAdmin + serviceUsageAdmin on the service project itself (grant after create, or condition the folder grant on resource.name) — not org-wide. Runner needs iam.serviceAccountTokenCreator on it."
}

# The least-privilege workspace CREATOR SA — the same GCP SA step 2.4 impersonates as a
# Databricks account admin. Here it is granted the read-only creator role on the service
# project. See databricks-account-setup/README.md (1.1) and workspace/ (step 2.4).
variable "databricks_account_admin_sa" {
  type        = string
  description = "Workspace creator SA email (db account-admin automation SA), granted the read-only creator role on the service project. No serviceAccount: prefix."
}

# End-state teardown toggle. TRUE during workspace creation (steps 2.1-2.4). After the
# workspace is RUNNING (2.8), flip to FALSE and re-apply to strip the read-only creator role
# — it is only needed at creation. See workspace-setup/creator-teardown/README.md.
variable "create_workspace_creator_role" {
  type        = bool
  default     = true
  description = "Whether to grant the read-only workspace-creator role on the service project. Set false in the End state (after step 2.8) to tear it down."
}
variable "google_region" {
  type    = string
  default = "us-central1"
}

# Break-glass Owner(s) of the service project — the authoritative roles/owner binding that
# removes the auto-granted Foundation-SA Owner. Set to a human break-glass GROUP, never a
# service account. Must be non-empty (an empty owner binding would lock everyone out).
variable "project_owners" {
  type        = list(string)
  description = "Members for the authoritative roles/owner binding (break-glass human group), e.g. [\"group:gcp-breakglass@example.com\"]."
  validation {
    condition     = length(var.project_owners) > 0
    error_message = "Set at least one break-glass owner (a human group) — an empty roles/owner binding removes all owners."
  }
}

# Dedicated node/compute SA for Databricks cluster VMs (no project roles). Its email is an
# output → feed it to workspace-sa-roles as compute_sa_email (the actAs target in step 2.5).
variable "node_sa_account_id" {
  type        = string
  default     = "databricks-node-sa"
  description = "account_id for the dedicated Databricks node SA created in the service project (no project roles)."
}

# The Cloud IAM team's SA (step 2.5) — granted iam.serviceAccountAdmin on the node SA
# RESOURCE here, so step 2.5 can bind the workspace SA's actAs without project-wide SA-admin.
variable "cloud_iam_sa" {
  type        = string
  description = "Cloud IAM team automation SA email (the step-2.5 runner). Granted serviceAccountAdmin on the node SA resource only. No serviceAccount: prefix."
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
