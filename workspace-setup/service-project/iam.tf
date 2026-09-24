# -----------------------------------------------------------------------------
# Strip the auto-granted Owner. Creating a project with resourcemanager.projectCreator
# auto-grants roles/owner to the creating (Foundation) SA. This AUTHORITATIVE binding
# resets roles/owner on the service project to the break-glass human group only, so the
# apply removes the SA's standing Owner. Set project_owners to that group — never a
# service account, never empty.
# -----------------------------------------------------------------------------
resource "google_project_iam_binding" "owner" {
  project = google_project.service.project_id
  role    = "roles/owner"
  members = var.project_owners
}
