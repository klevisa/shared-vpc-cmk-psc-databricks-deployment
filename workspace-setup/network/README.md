# 2.2 · Create network — Network Engineering

> ← [Phase 2 · Workspace Setup](../README.md) · [PoC playbook](../../README.md)

## What it does

Builds the network layer of the workspace, **inside the existing host project**:

- **VPC** — the private network the Databricks cluster VMs run in
- **Node subnet** (`/24`) — where cluster VMs get their IPs
  - **Each Databricks node uses two IP addresses**, so the subnet size caps the peak concurrent nodes across the whole workspace: `/25` ≈ 60 nodes, `/24` ≈ 120, `/23` ≈ 250, `/22` ≈ 500, `/21` ≈ 1,000, `/20` ≈ 2,000, `/19` ≈ 4,000. It **can't be resized after creation**, so size for growth up front. Full table: [Databricks GCP network sizing](https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/network-sizing).
- **PSC subnet** (`/28`) — holds the two Private Service Connect endpoint IPs
  - A `/28` is plenty; it only ever holds the two endpoint IPs (frontend + backend).
- **Firewall** — intra-cluster traffic + node subnet → PSC subnet egress (443 / 6666 / 8443-8451)
- **Default-deny egress (explicit)** — an EGRESS deny-all rule with two allows: internal (node↔node Spark, node→PSC) and Google APIs over the **restricted Private Google Access VIP** (`199.36.153.4/30`, via a route + a `googleapis.com` DNS zone). Control plane/relay go over PSC, not egress. Assumes clusters pull **no** public packages (PyPI/npm/Maven); if they must, add an allowlisted path or private mirrors first — see Additional info.
- **Two PSC endpoints** — frontend (UI / REST) and backend (secure cluster relay) toward Databricks
- **Private DNS zone** — makes `gcp.databricks.com` resolve to the private PSC IPs inside the VPC
- **Static subnet grants** — let the service project's compute agents place VMs on the shared subnet
- **Workspace-creator role (host project)** — defines the read-only creator custom role and grants it to the workspace creator SA (`databricks_account_admin_sa`), so step 2.4 can validate host-network settings during creation

## Pre-reqs

- **step 2.1 (`service-project/`) has run** — the service project exists and is attached to the existing Shared VPC host, and its APIs are enabled. (The host is a long-standing Shared VPC host with its APIs already on.)
- You have step 2.1's output `service_project_number` on hand for the Inputs below.

> This config does **not** create the host project or toggle the Shared VPC association — Cloud Foundation owns those (step 2.1). It only builds the network *inside* the host project.

## Privileges needed

On the impersonated network SA (`google_service_account_email`), against the **host** project:

- `roles/compute.networkAdmin` — VPC, subnets, addresses, PSC forwarding rules
- `roles/compute.securityAdmin` — firewall rules
- `roles/dns.admin` — the private DNS zone
- `roles/iam.roleAdmin` — define the read-only host-side workspace-creator custom role (not implied by the above)

The runner (person or CI) needs `roles/iam.serviceAccountTokenCreator` on that SA.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase** — paste the upstream output, don't invent:

- `vpc_network_project_id` : the existing **host** project id — the same one step 2.1 used (its `host_project` output)
- `google_service_project_number` : the **service** project number — from **step 2.1** output `service_project_number`; used to build the service-agent emails for the subnet grants

**✍️ Your decisions this phase** — names and sizes, pick them to fit your standards:

- `vpc_name` / `node_subnet_name` / `pe_subnet_name` : resource names
- `node_subnet_cidr` : node subnet size (see the sizing note under **What it does**)
- `pe_subnet_cidr` : PSC subnet range (a `/28` is enough)
- `workspace_pe` / `relay_pe` : names for the frontend / backend PSC endpoints
- `workspace_pe_ip_name` / `relay_pe_ip_name` : names for their internal IPs
- `google_service_account_email` : the network SA this config impersonates
- `databricks_account_admin_sa` : the workspace creator SA (the one step 2.4 impersonates) — granted the read-only creator role on the host project here
- `google_region` : the region — a decision, but it **must be the same** across every phase

**📋 Fixed lookups** — not a choice; copy the exact value for your region:

- `workspace_service_attachment` / `relay_service_attachment` : the region's Databricks PSC targets — frontend `plproxy-psc-endpoint-all-ports`, backend `ngrok-psc-endpoint` (from the Databricks region resource docs)

## Outputs

Copied into later phases' `terraform.tfvars` (or wired via `terraform_remote_state`):

- `host_project` : the host project id → **step 2.4 (workspace)**
- `vpc_name` : the VPC created for the workspace → **step 2.4 (workspace)**
- `node_subnet_name` : subnet the cluster VMs run in → **step 2.4 (workspace)** & **step 2.6 (post-workspace)**
- `workspace_pe` / `relay_pe` : frontend / backend PSC endpoint names → **step 2.4 (workspace)** (registered in the account)
- `frontend_pe_ip` / `backend_pe_ip` : the private endpoint IPs → **step 2.6 (post-workspace)** (DNS records)
- `private_zone_name` / `dns_name` : the private DNS zone → **step 2.6 (post-workspace)** (records)
- `front_end_psc_status` / `backend_psc_status` : PSC connection status — **PENDING** now, **ACCEPTED** after step 2.4 (see below)

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

Then hand the outputs to the next phases.

## Additional info

In this step the network team builds the private "landing zone" the workspace will live in — all of it inside the **host** project of the Shared VPC, so the network stays centrally owned.

We create a **VPC** (`vpc_name`) with two subnets: a **node subnet** (`node_subnet_cidr`) where the Databricks cluster VMs get their IPs, and a small **PSC subnet** (`pe_subnet_cidr`) that holds the two Private Service Connect endpoint IPs. The node subnet has Private Google Access on, so no-public-IP (NPIP) cluster nodes can still reach Google APIs like GCS and KMS. The **firewall** allows Spark driver↔executor traffic within the VPC and the node→PSC ports Databricks needs (443, 6666, 8443-8451).

**Default-deny egress, made explicit.** There is no NAT and no public IP, so nodes can't reach the internet regardless; the EGRESS deny-all rule keeps it that way and makes it tamper-evident (a later NAT or external IP still can't punch out). Two allow rules cover what a node legitimately needs: **internal** (node↔node Spark, node→PSC endpoints) and **Google APIs** over the **restricted VIP** (`199.36.153.4/30`) — a `google_apis_vip` route plus a private `googleapis.com` zone (`*.googleapis.com` → `restricted.googleapis.com` → the VIP) pin all Google-API traffic (GCS, KMS, BigQuery, Storage Transfer) into one `/30`. The Databricks **control plane and relay are reached over PSC** (the endpoint subnet), which the internal allow covers — they are not an egress concern, so the published Databricks IP ranges don't belong in the allowlist. This assumes clusters pull **no public packages** (PyPI/npm/Maven); if they must, add an allowlisted egress path or private mirrors *before* relying on the deny rule. If a needed Google API isn't on the restricted VIP, switch `google_apis_vip` to `private.googleapis.com` (`199.36.153.8/30`) and update the zone. **Verify at first cluster launch** that every Google API the workspace uses resolves over the VIP.

The two **PSC endpoints** are the private wire to Databricks: the **frontend** (`workspace_pe`) carries UI and REST, and the **backend** (`relay_pe`) carries the secure cluster-to-control-plane relay on port 6666. Each is a forwarding rule pointing at a Databricks *service attachment* for the region. They come up **PENDING** — a PSC endpoint isn't live until the *producer* (Databricks) accepts the connection, which happens when the Data Platform team registers these endpoints in the account (step 2.4). After that, re-run `terraform output` and they'll read **ACCEPTED**.

We also create the **private DNS zone** for `gcp.databricks.com` and bind it to the VPC. It's *authoritative* for that domain inside the VPC, so workspace hostnames resolve to the private PSC IPs and never leave the private path. The zone is created here, but its **A-records are added in step 2.6** — they need both the endpoint IPs (this phase) and the workspace URL (step 2.4), so they can't be written until the workspace exists.

Finally, the **static subnet grant** gives the service project's Compute Engine service agent subnet `get`/`use` on the node subnet — via a **2-permission custom role** (`lpw.databricks.network.agent.v2`) rather than the broader predefined `roles/compute.networkUser`. This is what lets a VM owned by the *service* project be placed on a subnet owned by the *host* project. The custom role drops `compute.subnetworks.useExternalIp` (clusters here are private); if clusters ever need external IPs, add it back or use the predefined role — verify at finalize (2.8). The Databricks **workspace service account** needs subnet access too, but it doesn't exist until the workspace is created, so that grant (its own narrow network role) happens in step 2.6.
