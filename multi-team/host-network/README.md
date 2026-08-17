# Phase 1 — host-network (Network Engineering)

**Creates (in the EXISTING HOST project):** VPC, node + PSC subnets, firewall, router/NAT,
two PSC endpoints (frontend/backend), the private DNS **zone**, and the static
`networkUser` subnet grants for the service project's compute agents.

> The host project and the Shared VPC association (host enablement + service-project
> attach) already exist — Cloud Foundation owns them (Phase 0). This config does not
> create the project or toggle the association; it only builds the network inside the host.

**Identity:** `compute.networkAdmin` + `compute.securityAdmin` + `dns.admin` on the HOST
project. Impersonated via `google_service_account_email`.

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
