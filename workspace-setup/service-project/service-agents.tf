# -----------------------------------------------------------------------------
# Google-managed service agents on the SERVICE project must exist before step 2.3
# grants them CMEK access, or the grant fails with 400 "... does not exist".
#
#   - compute-system  (VM disks)  -> created by enabling the Compute API (apis.tf).
#   - gs-project-accounts (GCS)   -> reading this data source both provisions and
#                                    returns the GCS service agent.
# -----------------------------------------------------------------------------
data "google_storage_project_service_account" "gcs" {
  project    = google_project.service.project_id
  depends_on = [google_project_service.service]
}
