# -----------------------------------------------------------------------------
# Dedicated node (compute) SA for Databricks cluster VMs, with NO project roles. Unity
# Catalog storage credentials carry data access and the workspace SA only needs actAs on
# it (step 2.5), so it needs no project-level grant. Using this instead of the GCE default
# SA keeps cluster VMs off the default SA's project Editor.
#
# Also enforce org policy constraints/iam.automaticIamGrantsForDefaultServiceAccounts so
# the default SA never receives Editor when the Compute API is enabled (customer, org-level).
# -----------------------------------------------------------------------------
resource "google_service_account" "node" {
  project      = google_project.service.project_id
  account_id   = var.node_sa_account_id
  display_name = "Databricks cluster node SA (no project roles)"
}

# Let the Cloud IAM team's SA (step 2.5) set IAM on THIS SA only, so it can bind the
# workspace SA's serviceAccountUser (actAs) in 2.5 WITHOUT holding project-wide
# serviceAccountAdmin. Resource-scoped — it can admin this one SA, nothing else.
resource "google_service_account_iam_member" "node_sa_admin_for_cloud_iam" {
  service_account_id = google_service_account.node.name
  role               = "roles/iam.serviceAccountAdmin"
  member             = "serviceAccount:${var.cloud_iam_sa}"
}
