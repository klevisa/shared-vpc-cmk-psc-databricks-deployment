# Phase 1 — host-network (Network Engineering)

## What it does

Builds the network layer of the workspace, **inside the existing host project**:

- **VPC** — the private network the Databricks cluster VMs run in
- **Node subnet** (`/24`) — where cluster VMs get their IPs
- **PSC subnet** (`/28`) — holds the two Private Service Connect endpoint IPs
- **Firewall** — intra-cluster traffic + node→PSC egress (443 / 6666 / 8443-8451)
- **Router + NAT** — outbound internet for nodes that have no public IP
- **Two PSC endpoints** — frontend (UI / REST) and backend (secure cluster relay) toward Databricks
- **Private DNS zone** — makes `gcp.databricks.com` resolve to the private PSC IPs inside the VPC
- **Static subnet grants** — let the service project's compute agents place VMs on the shared subnet

## Pre-reqs

- **Phase 0 (`foundation/`) has run** — the host project exists, the service project exists, the Shared VPC association is in place, and the APIs are enabled.
- You have Phase 0's output `service_project_number` on hand for the Inputs below.

> This config does **not** create the host project or toggle the Shared VPC association — Cloud Foundation owns those (Phase 0). It only builds the network *inside* the host project.

## Privileges needed

On the impersonated network SA (`google_service_account_email`), against the **host** project:

- `roles/compute.networkAdmin` — VPC, subnets, addresses, PSC forwarding rules
- `roles/compute.securityAdmin` — firewall rules
- `roles/dns.admin` — the private DNS zone

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`:

- `google_service_account_email` : the network SA this config impersonates
- `vpc_network_project_id` : the existing **host** project id
- `google_service_project_number` : the **service** project number *(from Phase 0 output `service_project_number`)* — used to build the service-agent emails for the subnet grants
- `google_region` : region for every resource here
- `vpc_name` / `node_subnet_name` / `node_subnet_cidr` / `pe_subnet_name` / `pe_subnet_cidr` : network names + CIDRs
- `workspace_pe` / `relay_pe` : names for the frontend / backend PSC endpoints
- `workspace_pe_ip_name` / `relay_pe_ip_name` : names for their internal IPs
- `workspace_service_attachment` / `relay_service_attachment` : the region's Databricks PSC targets — frontend `plproxy-psc-endpoint-all-ports`, backend `ngrok-psc-endpoint` (from the Databricks region resource docs)

## Outputs

Copied into later phases' `terraform.tfvars` (or wired via `terraform_remote_state`):

- `host_project` : the host project id → **Phase 3**
- `vpc_name` : the VPC created for the workspace → **Phase 3**
- `node_subnet_name` : subnet the cluster VMs run in → **Phases 3 & 4**
- `workspace_pe` / `relay_pe` : frontend / backend PSC endpoint names → **Phase 3** (registered in the account)
- `frontend_pe_ip` / `backend_pe_ip` : the private endpoint IPs → **Phase 4** (DNS records)
- `private_zone_name` / `dns_name` : the private DNS zone → **Phase 4** (records)
- `front_end_psc_status` / `backend_psc_status` : PSC connection status — **PENDING** now, **ACCEPTED** after Phase 3 (see below)

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

Then hand the outputs to the next phases.

## Additional info

In this step the network team builds the private "landing zone" the workspace will live in — all of it inside the **host** project of the Shared VPC, so the network stays centrally owned.

We create a **VPC** (`vpc_name`) with two subnets: a **node subnet** (`node_subnet_cidr`) where the Databricks cluster VMs get their IPs, and a small **PSC subnet** (`pe_subnet_cidr`) that holds the two Private Service Connect endpoint IPs. The node subnet has Private Google Access on, so no-public-IP (NPIP) cluster nodes can still reach Google APIs like GCS and KMS; a **Cloud Router + NAT** gives those nodes outbound internet without external IPs. The **firewall** allows Spark driver↔executor traffic within the VPC and the node→PSC ports Databricks needs (443, 6666, 8443-8451).

The two **PSC endpoints** are the private wire to Databricks: the **frontend** (`workspace_pe`) carries UI and REST, and the **backend** (`relay_pe`) carries the secure cluster-to-control-plane relay on port 6666. Each is a forwarding rule pointing at a Databricks *service attachment* for the region. They come up **PENDING** — a PSC endpoint isn't live until the *producer* (Databricks) accepts the connection, which happens when the Data Platform team registers these endpoints in the account (Phase 3). After that, re-run `terraform output` and they'll read **ACCEPTED**.

We also create the **private DNS zone** for `gcp.databricks.com` and bind it to the VPC. It's *authoritative* for that domain inside the VPC, so workspace hostnames resolve to the private PSC IPs and never leave the private path. The zone is created here, but its **A-records are added in Phase 4** — they need both the endpoint IPs (this phase) and the workspace URL (Phase 3), so they can't be written until the workspace exists.

Finally, the **static subnet grants** give the service project's Google-managed compute agents `compute.networkUser` on the node subnet — the permission that lets a VM owned by the *service* project be placed on a subnet owned by the *host* project. The Databricks **workspace service account** needs the same grant, but it doesn't exist until the workspace is created, so that one grant is deferred to Phase 4.
