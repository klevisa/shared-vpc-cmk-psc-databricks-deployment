# 2.6 · Post-workspace configuration — Network / Cloud IAM

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

The network-team handback — the two things that could only happen **after** the workspace SA
existed (step 2.4):

- **Workspace-SA network role** — defines a least-privilege custom **network role**
  (`compute.subnetworks.get` + `compute.subnetworks.use`) and binds it to the Databricks workspace
  SA on the host node subnet, so it can place cluster VMs across the Shared VPC boundary. (This
  replaces the broad predefined `roles/compute.networkUser`.)
- **DNS A-records** — writes the four records into the step 2.2 zone so workspace hostnames resolve
  to the private PSC IPs. The names derive from the workspace URL:
  - workspace URL / `dp-<workspace-id>` / `<region>.psc-auth` → frontend IP
  - `tunnel.<region>` → backend IP

Runs in parallel with steps 2.5 and 2.7. Once all three operator grants exist, step 2.8 finalizes
the workspace to RUNNING.

## Pre-reqs

- **steps 2.2 and 2.4 (PHASE 1) have run** — you have the network (subnet, DNS zone, endpoint IPs)
  from step 2.2 and the workspace SA + URL from step 2.4.

## Privileges needed

On the impersonated network SA (`google_service_account_email`) — the **same identity as step 2.2** — against the **host** project:

- `roles/compute.networkAdmin` — the subnet IAM binding
- `roles/dns.admin` — the DNS records
- `roles/iam.roleAdmin` — define the custom network role

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `vpc_network_project_id` : the host project id — from **step 2.2** `host_project`
- `node_subnet_name` : the node subnet — from **step 2.2** `node_subnet_name`
- `private_zone_name` : the DNS zone — from **step 2.2** `private_zone_name`
- `dns_name` : the zone's DNS name (trailing dot) — from **step 2.2** `dns_name`
- `frontend_pe_ip` / `backend_pe_ip` : the endpoint IPs — from **step 2.2**
- `gcp_workspace_sa` : the workspace service account — from **step 2.4** `gcp_workspace_sa`
- `workspace_url` : the workspace URL — from **step 2.4** `workspace_url` (record names derive from it)

**✍️ Your decisions this phase:**

- `google_service_account_email` : the network SA this config impersonates (same as step 2.2)
- `google_region` : the region — must be the same across every phase

**📋 Fixed lookups** — none.

## Outputs

None — this phase grants access and writes records rather than producing values for a downstream config.

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars
```

This is one of the three parallel operator grants (2.5/2.6/2.7). After all three, run step 2.8
(`workspace/` with `finalize=true`), then verify: a launched cluster reaches **RUNNING** (backend
relay), and `nslookup <workspace-url>` from inside the VPC returns the private frontend IP (see
[`../../docs/architecture.md`](../../docs/architecture.md) → Testing PSC).

## Additional info

Two grants had to wait until the workspace existed, which is why they're a separate phase run by the
network team (a "handback"). The workspace SA's CMEK grant is Security-owned and lives in the
parallel **step 2.7** (`cmek-workspace-grant/`); the project + resource operator roles are Cloud
IAM's **step 2.5** (`workspace-sa-roles/`).

First, the **workspace service account** (`gcp_workspace_sa`, minted by step 2.4 as
`db-<id>@prod-gcp-<region>`) is the principal that launches cluster VMs. It needs to *use* the host
**node subnet** across the project boundary — granted here via a least-privilege custom network role
(`compute.subnetworks.get`/`use`) bound at the subnet, rather than the broad predefined
`compute.networkUser`. The SA didn't exist when step 2.2 ran, so this grant lands here. Without it,
clusters fail to start.

Second, the **four DNS A-records** go into the private zone step 2.2 created. They need both the
endpoint IPs (step 2.2) and the workspace URL (step 2.4), so they couldn't be written earlier. Once
they exist, workspace hostnames resolve to the private PSC IPs inside the VPC and traffic never
leaves the private path.

With steps 2.5, 2.6, and 2.7 applied, step 2.8 finalizes the workspace: launch a cluster to confirm
the backend relay, and resolve/curl the workspace URL from inside the VPC to confirm the private
frontend.
