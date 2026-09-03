# -----------------------------------------------------------------------------
# MANAGED_SERVICES CMEK grant. Owned by Cloud Security / KMS.
#
# The Databricks WORKSPACE SA (minted by step 2.4) is what encrypts the workspace's
# managed-services data — notebook source, command results, secrets, Databricks SQL
# query history — in the CONTROL PLANE, using this customer-managed key. It therefore
# needs cryptoKeyEncrypterDecrypter on the key.
#
# In a least-privilege deployment Databricks does NOT grant itself this access (the
# key registration in step 2.4 uses the account API and never touches the key's IAM).
# We grant it here — the only party that can, since Security owns the key — and only
# after step 2.4 exists, since that's when the workspace SA email is known.
#
# STORAGE-use-case grants (the SERVICE project's compute-system + gs-project-accounts
# agents) are separate and already made in step 2.3's kms.tf.
# -----------------------------------------------------------------------------

resource "google_kms_crypto_key_iam_member" "workspace_sa_managed_services" {
  crypto_key_id = var.cmek_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.gcp_workspace_sa}"
}
