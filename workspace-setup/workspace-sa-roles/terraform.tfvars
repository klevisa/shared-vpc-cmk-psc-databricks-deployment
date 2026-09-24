# step 2.5 — workspace SA operator roles (service project). Example values — replace.
google_service_account_email = "cloud-iam-automation@example-service-project.iam.gserviceaccount.com"
google_project_name          = "example-service-project" # step 2.1 service_project_id
google_region                = "us-central1"

# PoC end date — the workspace-SA operator grants auto-expire after this (request.time).
poc_expiry = "2026-12-31T00:00:00Z"

# From step 2.4 (workspace, PHASE 1) outputs:
gcp_workspace_sa = "db-1234567890@prod-gcp-us-central1.iam.gserviceaccount.com"
workspace_id     = "1234567890"

# The compute/node SA the workspace SA impersonates as the VM identity — actAs is scoped to
# THIS SA only. Default = the service project's GCE default SA (step 2.1); replace the number.
compute_sa_email = "111111111111-compute@developer.gserviceaccount.com"

# Extra cluster-attached SAs the workspace SA must actAs (added per phase, e.g. Phase 5's
# keyless benchmark collector SA). Default none; re-apply with the SA appended, e.g.:
# additional_actas_service_accounts = ["gcp-data-collector@example-databricks-svc.iam.gserviceaccount.com"]
additional_actas_service_accounts = []
