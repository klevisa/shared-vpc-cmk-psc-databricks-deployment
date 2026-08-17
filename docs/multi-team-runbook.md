# Multi-team runbook — splitting this deployment across an org

This template can be deployed as one config by a single all-powerful automation
identity, or **split across teams** so each team runs only its slice with only its
own least-privilege identity. For a large organization (the examples below use
Yahoo-style team names) the split is the recommended shape: no mature org grants a
single service account *account admin + Owner-on-service + network-admin-on-host +
`xpnAdmin`* all at once, which is what the single-config version needs.

The value of splitting is **eliminating the god-identity**: each root config runs
with its team's own roles, and teams hand off **data** (Terraform outputs), never
shared credentials or shared state.

---

## Team ↔ slice map

| Slice | Files / resources | Team (Yahoo-style) | Standing identity it needs |
|---|---|---|---|
| **0. Foundation** | project vending, API enablement, Shared VPC host enable + service attach (`roles/compute.xpnAdmin`), Google service-agent creation, one-time Databricks account registration | **Cloud Foundation / Landing Zone (CCoE)** | Org/folder admin |
| **1. Host network** | `network.tf` (VPC, subnets, firewall, router, NAT), `psc.tf` (PSC IPs + forwarding rules), `dns.tf` **zone only**, static service-agent subnet grants from `iam-shared-vpc.tf` | **Network Engineering** | `compute.networkAdmin` + `compute.securityAdmin` + `dns.admin` on **HOST** |
| **2. CMEK** | `kms.tf` (keyring, key, grants to service-project compute-system + gs-project-accounts agents) | **Cloud Security ("The Paranoids") / KMS** | `cloudkms.admin` on **SERVICE** |
| **3. Databricks account + workspace** | `databricks.tf` (VPC-endpoint regs, private access settings, network config, CMEK registration, workspace, metastore) | **Data / Databricks Platform** | Databricks **account admin**; `serviceusage.serviceUsageConsumer` + read on **SERVICE** |
| **4. Post-workspace handback** | workspace-SA `networkUser` subnet grant (`iam-shared-vpc.tf`), `dns.tf` **records** (4 A-records) | **Network Engineering / Cloud IAM** | `compute.networkAdmin` + `dns.admin` on **HOST** |
| **5. Identity** | SCIM/SSO provisioning; delegated-admin assignment (`databricks_mws_permission_assignment`) | **Enterprise Identity / IT (Okta/Entra)** + Data Platform | IdP admin; account admin for the assignment |

> The role names above are the least-privilege set. See the README appendix
> "Least-privilege setup" for the predefined-vs-custom-role caveats
> (`pscCreate`, `bindPrivateDNSZone`).

---

## Why it's a pipeline, not six independent buttons

Three dependencies cross team boundaries. They are the reason the phases are ordered:

1. **PSC status is a two-team round-trip.** Network Eng creates the forwarding rules
   in Phase 1; they sit **PENDING**. They flip to **ACCEPTED** only after the Data
   Platform team *registers* those endpoints in the Databricks account (Phase 3),
   which auto-approves the connection. So "verify `ACCEPTED`" is a Network-Eng check
   performed **after** Phase 3.
2. **The workspace SA doesn't exist until the workspace does.** `db-<workspace-id>@prod-gcp-<region>`
   is minted by Phase 3, but it needs `roles/compute.networkUser` on the **host**
   subnet — Network Eng's resource. That grant is therefore Phase 4 (a handback),
   not Phase 1. Clusters cannot launch until it lands.
3. **DNS records need both sides.** The A-records need the PE IPs (Phase 1) **and**
   the workspace URL (Phase 3), so the *records* are Phase 4 even though the *zone*
   is Phase 1.

Everything else is parallel: **Phases 1 and 2 are independent** (network vs. KMS),
and **Phase 5 (SCIM/SSO)** runs on its own timeline entirely.

---

## Ordering with handoffs

```
Phase 0  Foundation      ── projects, APIs, Shared VPC attach, service agents, account admin
             │  hands off: host_project, service_project(+number), "Shared VPC attached"
     ┌───────┴───────────────┐
Phase 1 Network             Phase 2 Security / KMS       ← run in parallel
  VPC / subnet / FW / NAT      CMEK keyring + key
  PSC endpoints (PENDING)      grants to service agents
  DNS zone; agent subnet grants        │ hands off: cmek_key_id
     │ hands off: workspace_pe, relay_pe (names),
     │            frontend_pe_ip, backend_pe_ip, vpc, node_subnet, zone
     └───────┬───────────────────────┘
Phase 3  Data / Databricks Platform
  endpoint regs → network config → CMEK reg → PAS → workspace
  then: confirm PSC endpoints are now ACCEPTED
             │ hands off: workspace_id, workspace_url, gcp_workspace_sa
Phase 4  Network / Cloud IAM  (handback)
  workspace-SA networkUser on host subnet  +  4 DNS A-records
             → clusters can launch; workspace hostnames resolve to private IPs
Phase 5  Enterprise Identity  (any time, out of band)
  SCIM/SSO in Okta/Entra → users & groups sync into the Databricks ACCOUNT
  then Data Platform: assign a synced group as workspace ADMIN
```

---

## Step-by-step

### Phase 0 — Cloud Foundation / Landing Zone (prerequisites)

1. Vend the **host** project and the **service** project.
2. Enable the required APIs on both (compute, dns, cloudkms, iam, serviceusage; on the
   service project the Databricks-managed APIs it will need).
3. **Shared VPC**: enable the host project as a Shared VPC host and **attach** the
   service project. Requires `roles/compute.xpnAdmin` at the org/folder. (In-template
   equivalent: `manage_shared_vpc_association`; set it to `false` in Phase 1 because
   Foundation owns this step.)
4. **Trigger creation of the Google service agents** on the service project
   (e.g. by enabling the APIs / a no-op resource), so Phase 2's CMEK IAM grants don't
   fail with `400 does not exist`.
5. Grant each downstream team's automation SA its standing least-privilege roles, and
   grant the CI runners `roles/iam.serviceAccountTokenCreator` on those SAs.
6. Register the Databricks account (one-time) and make the **Data Platform** team's
   identity a Databricks **account admin**.

**Handoff:** `host_project_id`, `service_project_id`, `service_project_number`,
confirmation that Shared VPC is attached, "account admin granted."

### Phase 1 — Network Engineering (`host-network/`)

Runs with a host-project network identity. Set `manage_shared_vpc_association = false`
(Foundation did the association).

1. `network.tf` — VPC (custom mode), node subnet (`/24`, Private Google Access on),
   PSC subnet (`/28`), firewall (`allow_internal`, `node_to_psc`), router + NAT.
2. `psc.tf` — two internal IPs from the PSC subnet + two forwarding rules targeting the
   region's Databricks service attachments (frontend `plproxy`, backend `ngrok`). These
   will report **PENDING** until Phase 3.
3. `dns.tf` — the **private zone** for `gcp.databricks.com.` bound to the VPC. (Records
   come in Phase 4.)
4. `iam-shared-vpc.tf` — the **static** subnet `networkUser` grants to the service
   project's `<num>@cloudservices` and `service-<num>@compute-system` agents (these need
   only the service project number, no workspace).

**Handoff (outputs):** `vpc`, `node_subnet`, `pe_subnet`, `frontend_pe_ip`,
`backend_pe_ip`, `workspace_pe` (name), `relay_pe` (name), `private_zone_name`.

### Phase 2 — Cloud Security / KMS (`service-cmek/`)  *(parallel with Phase 1)*

Runs with `cloudkms.admin` on the service project.

1. `kms.tf` — keyring + crypto key in the **service** project; grant encrypt/decrypt to
   the service project's `compute-system` (VM disks) and `gs-project-accounts` (GCS)
   agents. (The `MANAGED_SERVICES` grant is added by Databricks at registration in
   Phase 3.)

**Handoff (output):** `cmek_key_id` (the full KMS resource id).

### Phase 3 — Data / Databricks Platform (`databricks-account/`)

Runs with the Databricks **account admin** identity. Reads Phase 1 + Phase 2 outputs
(via `terraform_remote_state` or passed tfvars).

1. `databricks.tf` — register both PSC endpoints (`project_id` = **host**), register the
   CMEK key (`use_cases = ["STORAGE","MANAGED_SERVICES"]`), create the private access
   settings (`public_access_enabled` — **immutable**), create the network config
   (`network_project_id` = **host**), then the workspace (`cloud_resource_container` =
   **service**), and the optional metastore assignment.
2. **Verify:** the Phase-1 PSC forwarding rules should now be **ACCEPTED**. If they are
   still PENDING, the endpoint registration/network config didn't match — reconcile
   before proceeding.

**Handoff (outputs):** `workspace_id`, `workspace_url`, `gcp_workspace_sa`.

### Phase 4 — Network Engineering / Cloud IAM handback (`post-workspace/`)

Runs with the host-project network identity again. Reads Phase 3 + Phase 1 outputs.

1. `iam-shared-vpc.tf` — grant `roles/compute.networkUser` on the host **node subnet** to
   the workspace SA (`gcp_workspace_sa` from Phase 3). Clusters cannot start without this.
2. `dns.tf` — the four A-records: workspace URL / `dp-<num>` / `<region>.psc-auth` →
   frontend IP; `tunnel.<region>` → backend IP.

**Result:** clusters launch (backend relay works) and workspace hostnames resolve to the
private PSC IPs inside the VPC (frontend works).

### Phase 5 — Enterprise Identity / IT (out of band, any time)

1. Configure SCIM in Okta/Entra so users **and groups** sync into the Databricks
   **account** (account-scoped, one-time). Optionally configure SSO/unified login.
2. Once a group (e.g. `platform-admins`) has synced, the **Data Platform** team assigns
   it as workspace `ADMIN` over the account API (reference read-only, don't manage the
   synced object as a Terraform resource — see `databricks.tf`). There is no bootstrap
   risk: until SCIM is live, the account admin from Phase 0 is already a full workspace
   admin.

---

## Handoff mechanism

Each root config has its **own backend/state** and its team's pipeline. Downstream
configs read upstream outputs read-only via `terraform_remote_state`:

```hcl
# databricks-account/ reading the network team's published state (read-only):
data "terraform_remote_state" "network" {
  backend = "gcs"
  config  = { bucket = "yahoo-tfstate-network", prefix = "databricks/host-network" }
}

# ...then reference, e.g.:
#   data.terraform_remote_state.network.outputs.workspace_pe
#   data.terraform_remote_state.network.outputs.frontend_pe_ip
```

This is what keeps credentials and state **per team** — the only thing that crosses a
team boundary is published output data, never a shared god-identity or a shared state
file.

---

## Physical layout

The split is implemented under [`../multi-team/`](../multi-team) — one root config per
phase, each with its own state, backend, and team identity:

```
multi-team/
├── host-network/        # Phase 1 — Network Eng      (host-project network identity)
├── service-cmek/        # Phase 2 — Security / KMS   (service-project cloudkms.admin)
├── databricks-account/  # Phase 3 — Data Platform    (account-admin identity)
└── post-workspace/      # Phase 4 — Network / IAM    (host-project network identity)
```

Each downstream config takes the upstream outputs as plain input variables (see each
folder's `terraform.tfvars`), or wire them via `terraform_remote_state` — see
[`../multi-team/README.md`](../multi-team/README.md). The single-config version in
[`../terraform/`](../terraform) remains valid for a one-team/one-identity deployment; the
split is the multi-team form of the same resources.
