# ---- Databricks identities ----
variable "databricks_account_id" { type = string }
variable "account_admin_sp" {
  type        = string
  description = "Account-admin service principal application id (OAuth M2M client_id). NCC, binding, and the network policy are all account-API objects."
}
variable "account_admin_sp_client_secret" {
  type        = string
  sensitive   = true
  description = "OAuth M2M client secret for account_admin_sp. Source via TF_VAR_account_admin_sp_client_secret; do not hard-code."
}

# ---- Handoff from step 2.4 (workspace) ----
variable "workspace_id" {
  type        = string
  description = "From workspace output workspace_id — the workspace the NCC (and optional network policy) is bound to."
}
variable "databricks_region" {
  type        = string
  description = "The workspace's region (e.g. us-central1). The NCC must be created in the SAME region as the workspace."
}

# ---- NCC ----
variable "ncc_name" {
  type        = string
  description = "Name for the Network Connectivity Config. Anchors serverless egress/connectivity for the bound workspace."
}

# ---- Optional serverless egress lockdown ----
variable "restrict_serverless_egress" {
  type    = bool
  default = true
  # ON by default: create a RESTRICTED_ACCESS policy and point the workspace at it so
  # serverless has NO internet egress. Set false to fall back to the account default
  # policy (FULL_ACCESS / open outbound).
  description = "Whether to create + attach a restricted serverless egress network policy. true = no internet egress."
}
variable "network_policy_id" {
  type        = string
  default     = "serverless-egress"
  description = "Identifier for the egress network policy (only used when restrict_serverless_egress = true)."
}
variable "egress_enforcement_mode" {
  type    = string
  default = "ENFORCED"
  # ENFORCED blocks egress not on the allowlist — with an empty internet allowlist that
  # means serverless cannot reach the internet. DRY_RUN only logs violations; use it
  # temporarily to observe what serverless needs (and allowlist required GCS storage
  # destinations, see README) before/after enforcing.
  description = "DRY_RUN (log only) or ENFORCED (block). ENFORCED = serverless blocked from the internet."
  validation {
    condition     = contains(["DRY_RUN", "ENFORCED"], var.egress_enforcement_mode)
    error_message = "egress_enforcement_mode must be DRY_RUN or ENFORCED."
  }
}
variable "allowed_internet_destinations" {
  type    = list(string)
  default = []
  # FQDNs serverless may reach when RESTRICTED_ACCESS is enforced (e.g. package indexes).
  # Storage destinations (your GCS buckets) are NOT set here — see the README: add them
  # before switching to ENFORCED, or serverless loses access to the catalogs.
  description = "Allowed outbound FQDNs (DNS names) under RESTRICTED_ACCESS, e.g. [\"pypi.org\", \"files.pythonhosted.org\"]."
}
