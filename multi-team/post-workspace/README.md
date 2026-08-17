# Phase 4 — post-workspace (Network / Cloud IAM handback)

## What it does

The final handback — the two things that could only happen **after** the workspace existed:

- **Workspace-SA subnet grant** — gives the Databricks workspace SA `compute.networkUser` on the host node subnet, so it can launch cluster VMs
- **DNS A-records** — writes the four records into the Phase 1 zone so workspace hostnames resolve to the private PSC IPs:
  - workspace URL / `dp-<num>` / `<region>.psc-auth` → frontend IP
  - `tunnel.<region>` → backend IP
- **(optional)** extra `networkUser` grants for feature-dependent agents (GKE robot, serverless VPC access, …)

After this, clusters start and the workspace is fully usable.

## Pre-reqs

- **Phases 1 and 3 have run** — you have the network (subnet, DNS zone, endpoint IPs) from Phase 1 and the workspace SA + URL from Phase 3.

## Privileges needed

On the impersonated network SA (`google_service_account_email`) — the **same identity as Phase 1** — against the **host** project:

- `roles/compute.networkAdmin` — the subnet IAM grant
- `roles/dns.admin` — the DNS records

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `vpc_network_project_id` : the host project id — from **Phase 1** `host_project`
- `node_subnet_name` : the node subnet — from **Phase 1** `node_subnet_name`
- `private_zone_name` : the DNS zone — from **Phase 1** `private_zone_name`
- `dns_name` : the zone's DNS name (trailing dot) — from **Phase 1** `dns_name`
- `frontend_pe_ip` / `backend_pe_ip` : the endpoint IPs — from **Phase 1**
- `gcp_workspace_sa` : the workspace service account — from **Phase 3** `gcp_workspace_sa`
- `workspace_url` : the workspace URL — from **Phase 3** `workspace_url` (the record names are derived from it)

**✍️ Your decisions this phase:**

- `google_service_account_email` : the network SA this config impersonates (same as Phase 1)
- `google_region` : the region — a decision, but it **must be the same** across every phase
- `additional_network_user_service_accounts` : optional extra agent emails needing `networkUser` on the subnet

**📋 Fixed lookups** — none.

## Outputs

None — this is the final phase; it grants access and writes records rather than producing values for a downstream config.

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars
```

Then verify: a launched cluster reaches **RUNNING** (backend relay), and `nslookup <workspace-url>` from inside the VPC returns the private frontend IP (see [`../../docs/architecture.md`](../../docs/architecture.md) → Testing PSC).

## Additional info

Two grants had to wait until the workspace existed, which is why they're a separate final phase run by the network team (a "handback").

First, the **workspace service account** (`gcp_workspace_sa`, minted by Phase 3 as `db-<id>@prod-gcp-<region>`) is the principal that actually launches cluster VMs. It needs `compute.networkUser` on the **host** node subnet to place those VMs across the project boundary — and it didn't exist when Phase 1 ran, so its grant lands here. Without it, clusters fail to start.

Second, the **four DNS A-records** go into the private zone Phase 1 created. They need both the endpoint IPs (Phase 1) and the workspace URL (Phase 3) — the record names are derived from the URL — so they couldn't be written earlier. Once they exist, workspace hostnames resolve to the private PSC IPs inside the VPC and traffic never leaves the private path.

With this phase applied, the deployment is complete: launch a cluster to confirm the backend relay works, and resolve/curl the workspace URL from inside the VPC to confirm the private frontend.
