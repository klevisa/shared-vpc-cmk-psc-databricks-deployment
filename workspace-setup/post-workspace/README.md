# 2.5 · Post-workspace configuration — Network / Cloud IAM

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

The final handback — the two things that could only happen **after** the workspace existed:

- **Workspace-SA subnet grant** — gives the Databricks workspace SA `compute.networkUser` on the host node subnet, so it can launch cluster VMs
- **DNS A-records** — writes the four records into the step 2.2 zone so workspace hostnames resolve to the private PSC IPs. The names derive from the workspace URL (e.g. `dp-<workspace-id>`, where `<workspace-id>` is the numeric id in the workspace URL):
  - workspace URL / `dp-<workspace-id>` / `<region>.psc-auth` → frontend IP
  - `tunnel.<region>` → backend IP

After this, clusters start and the workspace is fully usable.

## Pre-reqs

- **steps 2.2 and 2.4 have run** — you have the network (subnet, DNS zone, endpoint IPs) from step 2.2 and the workspace SA + URL from step 2.4.

## Privileges needed

On the impersonated network SA (`google_service_account_email`) — the **same identity as step 2.2** — against the **host** project:

- `roles/compute.networkAdmin` — the subnet IAM grant
- `roles/dns.admin` — the DNS records

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `vpc_network_project_id` : the host project id — from **step 2.2** `host_project`
- `node_subnet_name` : the node subnet — from **step 2.2** `node_subnet_name`
- `private_zone_name` : the DNS zone — from **step 2.2** `private_zone_name`
- `dns_name` : the zone's DNS name (trailing dot) — from **step 2.2** `dns_name`
- `frontend_pe_ip` / `backend_pe_ip` : the endpoint IPs — from **step 2.2**
- `gcp_workspace_sa` : the workspace service account — from **step 2.4** `gcp_workspace_sa`
- `workspace_url` : the workspace URL — from **step 2.4** `workspace_url` (the record names are derived from it)

**✍️ Your decisions this phase:**

- `google_service_account_email` : the network SA this config impersonates (same as step 2.2)
- `google_region` : the region — a decision, but it **must be the same** across every phase

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

First, the **workspace service account** (`gcp_workspace_sa`, minted by step 2.4 as `db-<id>@prod-gcp-<region>`) is the principal that actually launches cluster VMs. It needs `compute.networkUser` on the **host** node subnet to place those VMs across the project boundary — and it didn't exist when step 2.2 ran, so its grant lands here. Without it, clusters fail to start.

Second, the **four DNS A-records** go into the private zone step 2.2 created. They need both the endpoint IPs (step 2.2) and the workspace URL (step 2.4) — the record names are derived from the URL — so they couldn't be written earlier. Once they exist, workspace hostnames resolve to the private PSC IPs inside the VPC and traffic never leaves the private path.

With this phase applied, the deployment is complete: launch a cluster to confirm the backend relay works, and resolve/curl the workspace URL from inside the VPC to confirm the private frontend.
