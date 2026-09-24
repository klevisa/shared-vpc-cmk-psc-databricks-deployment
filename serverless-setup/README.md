# 4. Serverless Setup

> ← Back to the [PoC playbook](../README.md)

**Purpose:** bring **serverless compute** into the workspace and let it reach the data.
**Owner:** Cloud/Network Security + Data Platform.
**Produces:** a Network Connectivity Configuration (NCC) bound to the workspace, the perimeter
ingress that admits serverless, and the serverless egress controls.

Serverless does **not** run in the Shared VPC — it runs in Databricks-owned GCP projects — so
the classic networking (subnets, PSC backend) doesn't govern it. Two account-level
controls do: a **Network Connectivity Config (NCC)** and a **serverless egress network
policy**. (The Photon benchmark runs on classic job clusters, so serverless is a workspace
capability here, not part of the measurement path.)

> **Perimeter changes are split across Phases 3 and 4 on purpose.** Phase 3 adds the ingress
> for data access; this phase adds what serverless needs. They could be one perimeter change
> for efficiency, but they're kept separate so you can reason about "data access" and
> "serverless" independently.

## 4.1 · Update VPC-SC perimeter

- create a Network Connectivity Config in the workspace's region and **bind it to the workspace** — the anchor for serverless egress/connectivity
- ensure the VPC-SC ingress is **source-pinned to include Databricks' serverless-compute project numbers** for your region (the pin lives in [`../data-access`](../data-access/README.md)'s `databricks_source_projects`) — those entries are what admit the serverless plane to the catalogs

## 4.2 · Firewall rules for serverless

- create a `RESTRICTED_ACCESS` serverless egress **network policy**, `ENFORCED` with an **empty internet allowlist**, so serverless has **no internet egress** (see the rollout note below to observe in `DRY_RUN` first)
- **allowlist Databricks' serverless-compute outbound IPs on your firewall** — see the automation note below

> **You must automate the serverless outbound-IP allowlist.** Databricks publishes the
> serverless-compute outbound IPs at
> [ip-domain-region → Outbound IPs for serverless compute (firewall)](https://docs.databricks.com/gcp/en/resources/ip-domain-region#outbound-ips-for-serverless-compute-firewall-preview).
> **Unlike the source-pinning project numbers in 4.1 (which are stable), these IP ranges
> rotate** — it's a preview feed with a timestamp. A one-time manual firewall entry **will
> silently break** when the list changes. So you'll need automation that periodically fetches
> `ip-ranges.json`, diffs it, and updates the firewall allowlist. Plan for this as an ongoing
> operational responsibility for your team — not a one-time manual step.

> **How serverless reaches the data.** Serverless reads the catalogs through Unity Catalog,
> as the storage-credential SA — and that data access is admitted by the **VPC-SC ingress
> rule** in [`../data-access`](../data-access/) (`catalog-readonly.tf` /
> `catalog-readwrite.tf`). That ingress is source-pinned via `databricks_source_projects` to
> Databricks' control-plane **and serverless-compute** project numbers — the serverless-compute
> entries are what admit this serverless plane. In short: this stage enables serverless; the
> `data-access` ingress, pinned to include the serverless-compute projects, is what lets it
> reach the data.

## Pre-reqs

- **Workspace setup complete** (`workspace-setup/`); you have the `workspace_id` (step 2.4 output) and its region.
- **Account admin exists** (prereq) — the identity this config impersonates.
- The `data-access` ingress is source-pinned to include the **serverless-compute** project numbers for your region (see [`../data-access`](../data-access/README.md) and the [ip-domain-region table](https://docs.databricks.com/gcp/en/resources/ip-domain-region)) — that's what admits serverless to the data.

## Privileges needed

| Identity | Does | Team | Rights |
|---|---|---|---|
| `account_admin_sp` | creates the NCC, binds it, sets the network policy | (from prereqs) | Databricks **account admin** SP (OAuth) |

`account_admin_sp` authenticates via OAuth M2M (client id + secret) — no impersonation. Everything here is the Databricks **account API**; no GCP resources are created, so no GCP roles are needed.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase:**

- `workspace_id` : from **step 2.4** (`workspace`) output `workspace_id`
- `databricks_region` : the workspace's region — the NCC **must** match it
- `databricks_account_id` : your Databricks account id

**✍️ Your decisions this phase:**

- `account_admin_sp` + `account_admin_sp_client_secret` : the account-admin SP application id + OAuth secret (source the secret via `TF_VAR_account_admin_sp_client_secret`)
- `ncc_name` : a name for the Network Connectivity Config
- `restrict_serverless_egress` : `true` (locked down — no internet egress, default) or `false` (account default / open egress)
- `network_policy_id` / `egress_enforcement_mode` (default `ENFORCED`) / `allowed_internet_destinations` (default empty = no internet)

## Outputs

- `network_connectivity_config_id` / `ncc_name` : the NCC bound to the workspace
- `serverless_network_policy_id` : the egress policy id (null unless `restrict_serverless_egress = true`)

## How to run

```bash
terraform init && terraform apply -var-file=terraform.tfvars && terraform output
```

## Additional info

**The NCC is the whole point for serverless networking.** Because serverless runs in
Databricks projects rather than your VPC, you can't govern it with VPC firewall rules or
subnets. The NCC is what gives you a handle: it anchors the serverless plane's egress and
exposes **stable, per-region Databricks project IDs** — the values you'd add to the
`data-access` VPC-SC ingress (`databricks_source_projects`) and to firewall allowlists.
Those project numbers are stable; the **IP ranges** are the churny part (see the firewall
TODO in `workspace-setup/network/network.tf` and
[`ip-ranges.json`](https://www.databricks.com/networking/v1/ip-ranges.json)).

**Egress lockdown is ON — serverless has no internet egress.** The policy is
`RESTRICTED_ACCESS` + `ENFORCED` with an **empty internet allowlist**, so serverless can't
reach the internet. One caveat: `ENFORCED` also blocks reads of your own **GCS buckets**
unless they're allowlisted. This config models only `allowed_internet_destinations` (FQDNs),
**not** storage destinations — so if serverless workloads need the read-only/read-write
catalogs, **allowlist your GCS buckets as storage destinations** on the policy (per the
[serverless egress-control docs](https://docs.databricks.com/gcp/en/security/network/serverless-network-security/manage-network-policies));
that is private access, not internet egress. To de-risk a rollout you can temporarily set
`egress_enforcement_mode = "DRY_RUN"` to log (not block) violations, learn what serverless
needs, complete the storage allowlist, then return to `ENFORCED`. Keep
`allowed_internet_destinations` empty to preserve no-internet egress.

**Provider version.** The NCC binding and network-policy resources require a recent provider;
this config pins `databricks >= 1.116.0`. Confirm the resources apply cleanly on your provider
version in a non-production workspace first. Example values — replace before applying.
