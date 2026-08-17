# Phase 1 — host-network (Network Engineering)

**Creates (HOST project):** VPC, node + PSC subnets, firewall, router/NAT, two PSC
endpoints (frontend/backend), the private DNS **zone**, and the static `networkUser`
subnet grants for the service project's compute agents. Optionally enables the Shared VPC
association (`manage_shared_vpc_association`).

**Identity:** `compute.networkAdmin` + `compute.securityAdmin` + `dns.admin` on the HOST
project (+ `compute.xpnAdmin` if managing the association). Impersonated via
`google_service_account_email`.

**Inputs:** project ids/number, region, network names/CIDRs, PSC endpoint names, region
service attachments (all in `terraform.tfvars`).

**Outputs → Phase 3 & 4:** `host_project`, `vpc_name`, `node_subnet_name`, `workspace_pe`,
`relay_pe`, `frontend_pe_ip`, `backend_pe_ip`, `private_zone_name`, `dns_name`, plus PSC
status.

> The PSC endpoints report **PENDING** here — they flip to **ACCEPTED** after Phase 3
> registers them. Records for the DNS zone are added in Phase 4.

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```
