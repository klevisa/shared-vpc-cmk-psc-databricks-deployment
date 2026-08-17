# Multi-team runbook

This deployment is **split across teams** — each team runs one Terraform config with only
its own least-privilege identity, and teams hand off **data** (Terraform outputs), never
shared credentials or shared state. This is the shape a large organization needs: no single
service account should hold *account admin + Owner-on-service + network-admin-on-host +
`xpnAdmin`* all at once.

This page explains which team owns each phase and why the order matters. For the operational
index (commands, the handoff table) see [`../multi-team/README.md`](../multi-team/README.md).

---

## Team ↔ slice map

| Slice | Config / resources | Team | Standing identity it needs |
|---|---|---|---|
| **0. Foundation** | `foundation/` — create the service project, enable APIs on both projects, establish the Shared VPC relationship (host enable + attach), provision the GCS service agent. The **host project already exists** | **Cloud Foundation / Landing Zone** | org/folder: `resourcemanager.projectCreator`, `billing.user`, `compute.xpnAdmin`, `resourcemanager.projectIamAdmin` |
| **1. Host network** | `host-network/` — VPC, subnets, firewall, router, NAT, PSC IPs + forwarding rules, DNS **zone**, static service-agent subnet grants | **Network Engineering** | `compute.networkAdmin` + `compute.securityAdmin` + `dns.admin` on **HOST** |
| **2. CMEK** | `service-cmek/` — keyring, key, grants to service-project compute-system + gs-project-accounts agents | **Cloud Security / KMS** | `cloudkms.admin` on **SERVICE** |
| **3. Databricks account + workspace** | `databricks-account/` — VPC-endpoint regs, private access settings, network config, CMEK registration, workspace, metastore | **Data / Databricks Platform** | Databricks **account admin**; `serviceusage.serviceUsageConsumer` + read on **SERVICE** |
| **4. Post-workspace handback** | `post-workspace/` — workspace-SA `networkUser` subnet grant + DNS **records** (4 A-records) | **Network Engineering / Cloud IAM** | `compute.networkAdmin` + `dns.admin` on **HOST** |
| **5. Identity** | SCIM/SSO provisioning; delegated-admin assignment (`databricks_mws_permission_assignment`) | **Enterprise Identity / IT (Okta/Entra)** + Data Platform | IdP admin; account admin for the assignment |

> The role names above are the least-privilege set. See
> [`identity-and-access.md`](identity-and-access.md) for the full role breakdown and the
> predefined-vs-custom-role caveats (`pscCreate`, `bindPrivateDNSZone`).

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
Phase 0  Foundation      ── create service project, enable APIs, Shared VPC host+attach, GCS agent
             │  (host project already exists)   hands off: service_project_id (+number)
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

### Phase 0 — Cloud Foundation / Landing Zone (`foundation/`)

Runs with an org/folder-level identity. The **host project already exists** and is only
referenced; this config creates and wires everything else the later phases assume:

1. **Create the service project** (`google_project`) under an org or folder, linked to a
   billing account.
2. **Enable the APIs** on both the host and the service project (`compute, dns, cloudkms,
   iam, iamcredentials, cloudresourcemanager, serviceusage, storage`).
3. **Establish the Shared VPC relationship** — enable the host as a Shared VPC host and
   **attach** the service project (`roles/compute.xpnAdmin`).
4. **Provision the service agents** — the GCS agent via a data source, and the compute
   agent by enabling the Compute API — so Phase 2's CMEK grants don't fail with
   `400 does not exist`.

**Handoff (outputs):** `service_project_id`, `service_project_number`, `host_project`.

Two items are **not** in this config and are set up once, out of band:
- Each downstream team's automation SA and its runner's `iam.serviceAccountTokenCreator`
  (an IAM bootstrap the automation can't grant itself).
- Registering the Databricks account and making the Data Platform SA an **account admin**
  (a Databricks-side action — see [`identity-and-access.md`](identity-and-access.md)).

### Phase 1 — Network Engineering (`host-network/`)

Runs with a host-project network identity. The host project and the Shared VPC association
already exist (Phase 0); this config only creates the network **inside** the host project.

1. `network.tf` — VPC (custom mode), node subnet (`/24`, Private Google Access on),
   PSC subnet (`/28`), firewall (`allow_internal`, `node_to_psc`), router + NAT.
2. `psc.tf` — two internal IPs from the PSC subnet + two forwarding rules targeting the
   region's Databricks service attachments (frontend `plproxy`, backend `ngrok`). These
   will report **PENDING** until Phase 3.
3. `dns.tf` — the **private zone** for `gcp.databricks.com.` bound to the VPC. (Records
   come in Phase 4.)
4. `iam.tf` — the **static** subnet `networkUser` grants to the service
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

1. `iam.tf` — grant `roles/compute.networkUser` on the host **node subnet** to
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
team boundary is published output data, never a shared over-privileged identity or a shared state
file.

---

## Physical layout

The split is implemented under [`../multi-team/`](../multi-team) — one root config per
phase, each with its own state, backend, and team identity:

```
multi-team/
├── foundation/          # Phase 0 — Cloud Foundation  (org/folder identity)
├── host-network/        # Phase 1 — Network Eng       (host-project network identity)
├── service-cmek/        # Phase 2 — Security / KMS    (service-project cloudkms.admin)
├── databricks-account/  # Phase 3 — Data Platform     (account-admin identity)
└── post-workspace/      # Phase 4 — Network / IAM     (host-project network identity)
```

Each downstream config takes the upstream outputs as plain input variables (see each
folder's `terraform.tfvars`), or wire them via `terraform_remote_state` — see
[`../multi-team/README.md`](../multi-team/README.md).
