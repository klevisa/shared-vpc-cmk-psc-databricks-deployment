# ============================================================================
# Serverless setup — ILLUSTRATIVE values. Runs after the workspace exists.
# ============================================================================

# ---- Databricks identities ----
databricks_account_id = "00000000-0000-0000-0000-000000000000"
account_admin_sp      = "00000000-0000-0000-0000-0000000000aa" # account-admin SP application id (OAuth client_id)
# Source the OAuth secret from env: export TF_VAR_account_admin_sp_client_secret=...
account_admin_sp_client_secret = "REPLACE_VIA_TF_VAR_ENV"

# ---- from step 2.4 (workspace) ----
workspace_id      = "1234567890123456"
databricks_region = "us-central1" # MUST match the workspace region

# ---- NCC ----
ncc_name = "serverless-ncc"

# ---- Optional serverless egress lockdown (off by default) ----
restrict_serverless_egress = false
network_policy_id          = "serverless-egress"
egress_enforcement_mode    = "DRY_RUN" # flip to ENFORCED only after the allowlist is complete
allowed_internet_destinations = [
  # "pypi.org",
  # "files.pythonhosted.org",
]
