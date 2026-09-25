# -----------------------------------------------------------------------------
# Workspace SA OPERATOR roles on the SERVICE project. Owned by Cloud IAM.
#
# This is the step that was missing: it authorizes the Databricks workspace service
# account (minted by step 2.4) to actually CREATE the workspace's resources — GCS
# buckets (storage.buckets.create) and cluster VMs (compute.instances.create) — in the
# service project. Without it the step-2.8 finalize can never bring the workspace RUNNING.
#
# Two custom roles (least-privilege flow), both on the SERVICE project:
#   - Project role  : project-wide read (list/get) only.
#   - Resource role : create/delete/use, scoped to this workspace's resources by IAM condition.
# actAs is granted on the compute SA only (roles/iam.serviceAccountUser, below), not
# project-wide. Network role (subnet) = step 2.6; CMEK grant = step 2.7.
#
# Permission lists source of truth (re-verify in review):
#   https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/sa-permissions
#
# NOTE: this step's SA needs roles/iam.roleAdmin + roles/resourcemanager.projectIamAdmin on the
# SERVICE project. It also needs to set IAM on the compute SA (for the actAs binding) — but that
# is granted on the SA RESOURCE in step 2.1 (node-sa.tf), so NO project-wide serviceAccountAdmin.
# -----------------------------------------------------------------------------

resource "google_project_iam_custom_role" "project_role" {
  project     = var.google_project_name
  role_id     = "lpw.databricks.project.role.v2"
  title       = "Databricks workspace SA project role"
  description = "Project-level read (list/get) for the Databricks workspace service account."
  permissions = [
    "compute.disks.list",
    "compute.globalOperations.list",
    "compute.instances.list",
    "compute.regionOperations.list",
    "compute.regions.get",
    "compute.reservations.get",
    "compute.reservations.list",
    "compute.spotAssistants.get",
    "compute.zoneOperations.list",
    "compute.zones.get",
    "compute.zones.list",
    # actAs removed — granted on the compute SA only (binding below).
    "resourcemanager.projects.get",
    "serviceusage.quotas.get",
    "serviceusage.services.list",
    "storage.buckets.list",
  ]
}

resource "google_project_iam_custom_role" "resource_role" {
  project     = var.google_project_name
  role_id     = "lpw.databricks.resource.role.v2"
  title       = "Databricks workspace SA resource role"
  description = "Create/manage the workspace's disks, instances, and buckets (scoped by IAM condition)."
  permissions = [
    "compute.disks.create",
    "compute.disks.delete",
    "compute.disks.get",
    "compute.disks.resize",
    "compute.disks.setLabels",
    "compute.disks.update",
    "compute.disks.use",
    "compute.disks.useReadOnly",
    "compute.instances.attachDisk",
    "compute.instances.create",
    "compute.instances.delete",
    "compute.instances.detachDisk",
    "compute.instances.get",
    "compute.instances.getGuestAttributes",
    "compute.instances.getSerialPortOutput",
    "compute.instances.setLabels",
    "compute.instances.setMetadata",
    "compute.instances.setServiceAccount",
    "compute.instances.setTags",
    "compute.instances.update",
    "storage.buckets.create",
    "storage.buckets.delete",
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.buckets.setIamPolicy",
    "storage.buckets.update",
    "storage.multipartUploads.abort",
    "storage.multipartUploads.create",
    "storage.multipartUploads.list",
    "storage.multipartUploads.listParts",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
  ]
}

# Project role — granted project-wide (its permissions are read/actAs only).
resource "google_project_iam_member" "project_role" {
  project = var.google_project_name
  role    = google_project_iam_custom_role.project_role.id
  member  = "serviceAccount:${var.gcp_workspace_sa}"

  # PoC time-box: self-expires at var.poc_expiry via a request.time IAM condition, so the
  # grant lapses even if teardown slips. Extend/shorten by editing poc_expiry and re-applying.
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# Resource role — granted project-wide but SCOPED by IAM condition to resources whose
# names carry both "databricks" and this workspace's id (its buckets/disks/instances).
resource "google_project_iam_member" "resource_role" {
  project = var.google_project_name
  role    = google_project_iam_custom_role.resource_role.id
  member  = "serviceAccount:${var.gcp_workspace_sa}"
  # A binding takes ONE condition, so the workspace-scoping expression and the PoC
  # time-box are AND-ed together: manage only THIS workspace's resources, and only until
  # var.poc_expiry (request.time). After expiry the workspace SA can no longer create/manage.
  #
  # The scoping matches the CONTIGUOUS token "databricks-<workspace_id>" (the workspace's
  # bucket/instance/disk prefix), not "databricks" and "<workspace_id>" as two independent
  # substrings — so a resource that merely contains both tokens in different positions cannot
  # match. resource.name is a full path (projects/_/buckets/... vs projects/<p>/zones/<z>/
  # instances/...), so a single startsWith() on the whole path can't cover both types; the
  # contiguous extract() is the portable tightening. VERIFY at finalize (2.8) that the
  # workspace SA can create/manage this workspace's instances and disks with this condition.
  condition {
    title       = "scope-to-workspace-${var.workspace_id}-poc"
    description = "Scope to this workspace's own resources AND auto-expire after the PoC end date."
    expression  = "resource.name.extract(\"{x}databricks-${var.workspace_id}\") != \"\" && request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# actAs on the compute SA only — lets the workspace SA set it as the cluster VM identity.
resource "google_service_account_iam_member" "workspace_sa_act_as_compute" {
  service_account_id = "projects/${var.google_project_name}/serviceAccounts/${var.compute_sa_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.gcp_workspace_sa}"

  # PoC time-box (request.time).
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# actAs on any ADDITIONAL cluster-attached SAs (beyond the compute SA) — e.g. the Phase 5
# benchmark collector SA. Same resource-level roles/iam.serviceAccountUser, added in state
# (re-apply with the SA appended to the list) rather than a manual gcloud grant.
resource "google_service_account_iam_member" "workspace_sa_act_as_additional" {
  for_each           = toset(var.additional_actas_service_accounts)
  service_account_id = "projects/${var.google_project_name}/serviceAccounts/${each.value}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.gcp_workspace_sa}"

  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}
