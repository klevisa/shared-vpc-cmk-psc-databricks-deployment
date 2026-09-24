# -----------------------------------------------------------------------------
# The SERVICE project (the host project already exists and is only referenced).
# Created under an org or a folder, linked to a billing account.
# -----------------------------------------------------------------------------
resource "google_project" "service" {
  name            = var.service_project_name
  project_id      = var.service_project_id
  org_id          = var.org_id != "" ? var.org_id : null
  folder_id       = var.folder_id != "" ? var.folder_id : null
  billing_account = var.billing_account

  # No default network — the workspace uses the Shared VPC. This stops the permissive
  # default-allow-ssh/rdp/icmp rules from being created. (Provider deletes it after the
  # Compute API is enabled; needs compute.networks.delete, covered by the creator identity.)
  auto_create_network = false
}
