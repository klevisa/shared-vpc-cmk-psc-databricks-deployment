output "network_connectivity_config_id" {
  value       = databricks_mws_network_connectivity_config.this.network_connectivity_config_id
  description = "The NCC id bound to the workspace."
}
output "ncc_name" {
  value = databricks_mws_network_connectivity_config.this.name
}
output "serverless_network_policy_id" {
  value       = one(databricks_account_network_policy.serverless_egress[*].network_policy_id)
  description = "The egress network policy id if restrict_serverless_egress = true, else null."
}
