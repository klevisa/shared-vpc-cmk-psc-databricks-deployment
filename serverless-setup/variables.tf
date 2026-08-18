# ---- Databricks identities ----
variable "databricks_account_id" { type = string }
variable "account_admin_sa" {
  type        = string
  description = "The Databricks ACCOUNT ADMIN SA (from prereqs). NCC, binding, and the network policy are all account-API objects."
}

# ---- Handoff from Phase 3 (databricks-account) ----
variable "workspace_id" {
  type        = string
  description = "From databricks-account output workspace_id — the workspace the NCC (and optional network policy) is bound to."
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
  default = false
  # OFF by default: the workspace uses the account default policy (FULL_ACCESS) and
  # serverless has open outbound. ON: create a RESTRICTED_ACCESS policy and point the
  # workspace at it. Start in DRY_RUN (see egress_enforcement_mode) to observe first.
  description = "Whether to create + attach a restricted serverless egress network policy. false = open egress (default policy)."
}
variable "network_policy_id" {
  type        = string
  default     = "poc-serverless-egress"
  description = "Identifier for the egress network policy (only used when restrict_serverless_egress = true)."
}
variable "egress_enforcement_mode" {
  type    = string
  default = "DRY_RUN"
  # DRY_RUN logs egress-policy violations but blocks nothing — the safe way to roll this
  # out: watch what serverless actually needs, complete the allowlist, THEN switch to
  # ENFORCED. Flipping straight to ENFORCED can break jobs/model-serving that reach the
  # internet or storage you haven't allowlisted yet.
  description = "DRY_RUN (log only) or ENFORCED (block). Start with DRY_RUN."
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
