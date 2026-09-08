# -----------------------------------------------------------------------------
# Workspace SA OPERATOR roles on the SERVICE project. Owned by Cloud IAM.
#
# This is the step that was missing: it authorizes the Databricks workspace service
# account (minted by step 2.4) to actually CREATE the workspace's resources — GCS
# buckets (storage.buckets.create) and cluster VMs (compute.instances.create) — in the
# service project. Without it the step-2.8 finalize can never bring the workspace RUNNING.
#
# Two custom roles (least-privilege flow), both on the SERVICE project:
#   - Project role  : project-wide read + actAs (broad but harmless).
#   - Resource role : the create/delete/use permissions, SCOPED to this workspace's
#                     resources via an IAM condition on the workspace id.
# The NETWORK role (subnet) is granted separately by the network team in step 2.6, and
# the CMEK grant by security in step 2.7.
#
# Source of truth for the exact permission lists + the IAM condition (re-verify in review):
#   https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/sa-permissions
#
# NOTE: needs roles/iam.roleAdmin (create custom roles) + roles/resourcemanager.projectIamAdmin
# (set IAM policy) on the SERVICE project on this step's SA.
# -----------------------------------------------------------------------------

resource "google_project_iam_custom_role" "project_role" {
  project     = var.google_project_name
  role_id     = "lpw.databricks.project.role.v2"
  title       = "Databricks workspace SA project role"
  description = "Project-level read + actAs for the Databricks workspace service account."
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
    "iam.serviceAccounts.actAs",
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
}

# Resource role — granted project-wide but SCOPED by IAM condition to resources whose
# names carry both "databricks" and this workspace's id (its buckets/disks/instances).
resource "google_project_iam_member" "resource_role" {
  project = var.google_project_name
  role    = google_project_iam_custom_role.resource_role.id
  member  = "serviceAccount:${var.gcp_workspace_sa}"
  condition {
    title       = "scope-to-workspace-${var.workspace_id}"
    description = "Limit resource management to this workspace's own resources."
    expression  = "resource.name.extract(\"{x}databricks\") != \"\" && resource.name.extract(\"{x}${var.workspace_id}\") != \"\""
  }
}
