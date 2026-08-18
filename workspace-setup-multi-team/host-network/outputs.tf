# Handoff → consumed by Phase 3 (databricks-account) and Phase 4 (post-workspace).
output "host_project" { value = var.vpc_network_project_id }
output "vpc_name" { value = google_compute_network.vpc.name }
output "node_subnet_name" { value = google_compute_subnetwork.node_subnet.name }
output "pe_subnet_name" { value = google_compute_subnetwork.pe_subnet.name }
output "frontend_pe_ip" { value = google_compute_address.frontend_pe_ip.address }
output "backend_pe_ip" { value = google_compute_address.backend_pe_ip.address }
output "workspace_pe" { value = google_compute_forwarding_rule.frontend_psc_ep.name }
output "relay_pe" { value = google_compute_forwarding_rule.backend_psc_ep.name }
output "private_zone_name" { value = google_dns_managed_zone.private.name }
output "dns_name" { value = google_dns_managed_zone.private.dns_name }

# PENDING until Phase 3 registers the endpoints; re-check after Phase 3 for ACCEPTED.
output "front_end_psc_status" { value = google_compute_forwarding_rule.frontend_psc_ep.psc_connection_status }
output "backend_psc_status" { value = google_compute_forwarding_rule.backend_psc_ep.psc_connection_status }
