# ---- Identity / projects ----
variable "google_service_account_email" {
  type        = string
  description = "Automation SA impersonated by the providers (single identity for both GCP resource creation and Databricks account/workspace auth). Prerequisites, granted before apply: account admin on Databricks; Owner on the service project; on the host project either Owner or the granular set compute.networkAdmin + compute.networkUser + dns.admin + resourcemanager.projectIamAdmin (it CREATES the VPC/subnets/firewall/PSC + the DNS zone and sets subnet/KMS IAM). Caller running Terraform needs iam.serviceAccountTokenCreator on this SA."
}

variable "google_project_name" {
  type        = string
  description = "SERVICE project: where the Databricks workspace GCE/GCS resources and the CMEK key live."
}

variable "google_service_project_number" {
  type        = string
  description = "Numeric project number of the SERVICE project. Used to build its Google-managed service-agent emails (CMEK grants + Shared VPC networkUser)."
}

variable "vpc_network_project_id" {
  type        = string
  description = "HOST project: owns the Shared VPC, subnets, firewall, PSC endpoints, and DNS."
}

variable "google_region" {
  type    = string
  default = "us-central1"
}

# ---- Shared VPC association ----
variable "manage_shared_vpc_association" {
  type        = bool
  default     = true
  description = "If true, this template enables the host project as a Shared VPC host and attaches the service project. Set false if your network team already configured Shared VPC."
}

variable "additional_network_user_service_accounts" {
  type        = list(string)
  default     = []
  description = "Extra service-account EMAILS (no 'serviceAccount:' prefix) that must hold compute.networkUser on the shared subnet, beyond the workspace SA and the service-project agents this template already grants. Populate with any feature-dependent agents your workspace surfaces (e.g. GKE robot service-<svc#>@container-engine-robot.iam.gserviceaccount.com, serverless VPC-access agent). The workspace SA (db-<workspace-id>@prod-gcp-<region>) is granted automatically."
}

# ---- Databricks account / workspace ----
variable "databricks_account_id" { type = string }
variable "databricks_workspace_name" { type = string }
variable "metastore_id" {
  type        = string
  default     = ""
  description = "Optional existing Unity Catalog metastore ID to assign. Empty = rely on auto-assignment."
}

variable "public_access_enabled" {
  type        = bool
  default     = false
  description = "IMMUTABLE after creation. false = fully private (PSC-only); true = public endpoint also reachable, gate with an IP access list. See README."
}

# ---- Network (created in the HOST project) ----
variable "vpc_name" { type = string }
variable "node_subnet_name" { type = string }
variable "node_subnet_cidr" { type = string }
variable "pe_subnet_name" { type = string }
variable "pe_subnet_cidr" { type = string }

# ---- PSC endpoints (HOST project) ----
variable "workspace_pe" { type = string }
variable "relay_pe" { type = string }
variable "workspace_pe_ip_name" { type = string }
variable "relay_pe_ip_name" { type = string }

# Region-specific Databricks service attachments.
# See https://docs.databricks.com/gcp/en/resources/ip-domain-region
variable "workspace_service_attachment" { type = string }
variable "relay_service_attachment" { type = string }

# ---- CMEK (SERVICE project) ----
variable "kms_keyring_name" { type = string }
variable "kms_key_name" { type = string }

# ---- Private DNS (HOST project) ----
variable "private_zone_name" {
  type    = string
  default = "databricks"
}
variable "dns_name" {
  type    = string
  default = "gcp.databricks.com." # trailing dot required
}
