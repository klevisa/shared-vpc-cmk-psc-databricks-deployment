# Handoff → these role bindings gate the step-2.8 finalize. No values are produced for a
# downstream config; the outputs below are informational (confirm the grants landed).
output "project_role_id" { value = google_project_iam_custom_role.project_role.id }
output "resource_role_id" { value = google_project_iam_custom_role.resource_role.id }
