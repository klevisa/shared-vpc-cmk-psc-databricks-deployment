# -----------------------------------------------------------------------------
# Workspace SA OPERATOR roles on the SERVICE project. Owned by Cloud IAM.
#
# This is the step that was missing: it authorizes the Databricks workspace service
# account (minted by step 2.4) to actually CREATE the workspace's resources — GCS
# buckets (storage.buckets.create) and cluster VMs (compute.instances.create) — in the
# service project. Without it the step-2.8 finalize can never bring the workspace RUNNING.
#
# Two custom roles (least-privilege flow), both on the SERVICE project:
#   - Project role  : project-wide read only (list/get). actAs is NOT here — see below.
#   - Resource role : the create/delete/use permissions, SCOPED to this workspace's
#                     resources via an IAM condition on the workspace id.
# The NETWORK role (subnet) is granted separately by the network team in step 2.6, and
# the CMEK grant by security in step 2.7.
#
# actAs SCOPING (tighter than the Databricks sa-permissions doc): the doc lists
# iam.serviceAccounts.actAs inside the project-wide role, but the workspace SA only needs
# actAs to set the COMPUTE SA as the cluster VM identity (compute.instances.setServiceAccount).
# Project-wide actAs would let it impersonate ANY SA in the project (incl. admin SAs). So we
# removed actAs from the project role and instead grant roles/iam.serviceAccountUser on the
# COMPUTE SA resource only (google_service_account_iam_member, below).
#
# Source of truth for the exact permission lists + the IAM condition (re-verify in review):
#   https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/sa-permissions
#
# NOTE: needs roles/iam.roleAdmin (create custom roles) + roles/resourcemanager.projectIamAdmin
# (set project IAM policy) on the SERVICE project on this step's SA — PLUS, because the
# compute-SA actAs binding sets IAM on a service-account RESOURCE (not the project),
# roles/iam.serviceAccountAdmin on the service project (projectIamAdmin does not cover it).
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
    # iam.serviceAccounts.actAs intentionally REMOVED — granted on the compute SA resource
    # only (roles/iam.serviceAccountUser), not project-wide. See the header + binding below.
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
  condition {
    title       = "scope-to-workspace-${var.workspace_id}-poc"
    description = "Scope to this workspace's own resources AND auto-expire after the PoC end date."
    expression  = "(resource.name.extract(\"{x}databricks\") != \"\" && resource.name.extract(\"{x}${var.workspace_id}\") != \"\") && request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# actAs — SCOPED to the compute SA only. This replaces the project-wide actAs that used to
# live in the project role: the workspace SA needs actAs solely to set the compute SA as the
# cluster VM identity (compute.instances.setServiceAccount). roles/iam.serviceAccountUser on
# THIS SA resource grants exactly iam.serviceAccounts.actAs on it — nothing else in the
# project. (Setting IAM on a service-account resource needs iam.serviceAccounts.setIamPolicy
# on this step's SA — see the header NOTE about roles/iam.serviceAccountAdmin.)
resource "google_service_account_iam_member" "workspace_sa_act_as_compute" {
  service_account_id = "projects/${var.google_project_name}/serviceAccounts/${var.compute_sa_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.gcp_workspace_sa}"

  # PoC time-box: self-expires at var.poc_expiry via a request.time IAM condition, matching
  # the other workspace-SA operator grants.
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}
