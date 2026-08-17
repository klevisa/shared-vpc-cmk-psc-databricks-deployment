# Phase 4 — post-workspace (Network / Cloud IAM handback)

**Creates (HOST project):** the `networkUser` grant on the node subnet for the Databricks
**workspace SA** (so clusters can launch), plus the four DNS **A-records** in the Phase-1
zone (so workspace hostnames resolve to the private PSC IPs).

**Identity:** same as Phase 1 — `compute.networkAdmin` + `dns.admin` on the HOST project.

**Inputs from Phase 1:** `node_subnet_name`, `private_zone_name`, `dns_name`,
`frontend_pe_ip`, `backend_pe_ip`. **From Phase 3:** `gcp_workspace_sa`, `workspace_url`.

**Result:** clusters launch (backend relay works) and workspace hostnames resolve
privately (frontend works). This is the final handback that makes the workspace usable.

```bash
terraform init && terraform apply -var-file=terraform.tfvars
```
