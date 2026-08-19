# 4. Serverless Setup

> ← Back to the [PoC playbook](../README.md)

**Purpose:** bring **serverless compute** into the workspace and let it reach the data.
**Owner:** Cloud/Network Security + Data Platform.
**Produces:** a Network Connectivity Configuration (NCC) bound to the workspace, the perimeter
ingress that admits serverless, and the serverless egress controls.

Serverless does **not** run in the Shared VPC — it runs in Databricks-owned GCP projects — so
the classic networking (subnets, PSC backend, NAT) doesn't govern it. Two account-level
controls do: a **Network Connectivity Config (NCC)** and a **serverless egress network
policy**. (The Photon benchmark runs on classic job clusters, so serverless is a workspace
capability here, not part of the measurement path.)

> **Perimeter changes are split across Phases 3 and 4 on purpose.** Phase 3 adds the ingress
> for data access; this phase adds what serverless needs. They could be one perimeter change
> for efficiency, but they're kept separate so the client can reason about "data access" and
> "serverless" independently.

## 4.1 · Update VPC-SC perimeter

- create a Network Connectivity Config in the workspace's region and **bind it to the workspace** — the anchor for serverless egress/connectivity
- ensure the VPC-SC ingress is **source-pinned to include Databricks' serverless-compute project numbers** for your region (the pin lives in [`../data-access`](../data-access/README.md)'s `databricks_source_projects`) — those entries are what admit the serverless plane to the catalogs

## 4.2 · Firewall rules for serverless

- create a `RESTRICTED_ACCESS` serverless egress **network policy** (allowed FQDNs you specify), defaulting to **`DRY_RUN`** so violations are logged, not blocked — roll out safely, then flip to `ENFORCED`
- **allowlist Databricks' serverless-compute outbound IPs on your firewall** — see the automation note below

> **You must automate the serverless outbound-IP allowlist.** Databricks publishes the
> serverless-compute outbound IPs at
> [ip-domain-region → Outbound IPs for serverless compute (firewall)](https://docs.databricks.com/gcp/en/resources/ip-domain-region#outbound-ips-for-serverless-compute-firewall-preview).
> **Unlike the source-pinning project numbers in 4.1 (which are stable), these IP ranges
> rotate** — it's a preview feed with a timestamp. A one-time manual firewall entry **will
> silently break** when the list changes. So the customer **must build automation** that
> periodically fetches `ip-ranges.json`, diffs it, and updates the firewall allowlist. Treat
> this as a required, customer-owned follow-up — not a one-time manual step.

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
| `account_admin_sa` | creates the NCC, binds it, sets the network policy | (from prereqs) | Databricks **account admin** |

The runner needs `roles/iam.serviceAccountTokenCreator` on `account_admin_sa`. Everything here is the Databricks **account API** — no GCP resources are created, so no GCP roles are needed.

## Inputs

Set in `terraform.tfvars`, grouped by where the value comes from:

**⬅️ Carried over from a previous phase:**

- `workspace_id` : from **step 2.4** (`workspace`) output `workspace_id`
- `databricks_region` : the workspace's region — the NCC **must** match it
- `databricks_account_id` : your Databricks account id

**✍️ Your decisions this phase:**

- `account_admin_sa` : the account admin (from prereqs)
- `ncc_name` : a name for the Network Connectivity Config
- `restrict_serverless_egress` : `false` (open egress, default) or `true` (locked down)
- `network_policy_id` / `egress_enforcement_mode` / `allowed_internet_destinations` : only when locking egress down — start `DRY_RUN`

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

**Egress lockdown — roll out in DRY_RUN first.** Switching serverless to
`RESTRICTED_ACCESS` + `ENFORCED` in one step commonly breaks things: jobs that `pip install`
from public indexes, model-serving build-time dependency fetches, and — importantly — reads
of your own **GCS buckets**. This config only models `allowed_internet_destinations`
(FQDNs). Before you flip to `ENFORCED`, you must **also allowlist your GCS buckets as
storage destinations** on the policy (per the
[serverless egress-control docs](https://docs.databricks.com/gcp/en/security/network/serverless-network-security/manage-network-policies)) —
otherwise serverless loses access to the read-only and read-write catalogs. The safe
sequence: apply with `DRY_RUN`, review the logged violations to learn exactly what
serverless needs, complete the allowlist, then set `egress_enforcement_mode = "ENFORCED"`.

**Provider version.** The NCC binding and network-policy resources require a recent provider;
this config pins `databricks >= 1.116.0`. Confirm the resources apply cleanly on your provider
version in a non-production workspace first. Example values — replace before applying.
