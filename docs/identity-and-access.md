# Identity & access

## Workspace admins — two scopes

There are **two different admins**, at two scopes. The deployment *requires* one and does
*not* create the other:

| | **Account admin** | **Workspace admin** |
|---|---|---|
| Scope | Whole Databricks account | This one workspace |
| Relationship | **Required** (prerequisite) | **Not** created |
| Why | Authorization to call the account API and create the workspace | Give a delegated human admin access to just this workspace |
| Needed for a working workspace? | Yes | No — the account admin already covers it |

The Data Platform identity that runs Phase 3 is an **account admin**, and account admins
hold workspace-admin implicitly on every workspace they create. So a fresh workspace is
fully administered with no extra resource — which is why nothing provisions a workspace
admin.

**To add a delegated admin** — a human who should administer *this* workspace without
being a full account admin:

1. **SCIM first.** Configure SCIM in your IdP (Okta/Entra) so the user/group syncs into
   the Databricks **account**. Account-scoped, one-time, done out of band before apply —
   an identity must exist at the account before it can be assigned to a workspace.
2. **Assign, don't create.** Reference the synced identity read-only and bind it as
   workspace `ADMIN` over the account API (worked example in
   [`../multi-team/databricks-account/databricks.tf`](../multi-team/databricks-account/databricks.tf)).
   Prefer assigning a **group** so admins are managed in the IdP, not in Terraform.

Both steps stay on `accounts.gcp.databricks.com`, so this works even when
`public_access_enabled = false`. There's no bootstrap risk: until SCIM is live, the
account admin is already a full workspace admin.

---

## The automation identities (GSA) vs Databricks account admin

Each config impersonates **its team's** automation service account
(`google_service_account_email`). Those SAs need standing in **two separate systems**,
granted independently — neither implies the other:

- **Google Cloud** — each is a GCP *service account* with the IAM roles for its slice
  (see below); this is what lets it create the service project, VPC, CMEK key, PSC
  endpoints, DNS, and cross-project IAM.
- **Databricks account** — the **Data Platform** SA (used by `databricks-account/`) must
  **also** be registered in the Databricks account as a **user** (username = the GSA
  email) and granted **account admin**, so the `databricks` provider's calls (workspace,
  network config, private access settings, CMEK registration) are authorized. The other
  teams' SAs need nothing in Databricks.

Being a GCP service account grants nothing in Databricks. A human account admin performs
the Databricks-side registration + account-admin grant **once** (nothing can grant the
very first account admin — chicken-and-egg); afterward the SA runs unattended.

> GCP specific: a GCP GSA federates to a Databricks **user**, not a service principal —
> register it as a user, not an SP.

---

## Least-privilege roles (per team)

Rather than granting each automation SA `Owner`, scope it to specific **predefined**
roles. Roles are based on the
[Databricks lpw template](https://github.com/bhavink/databricks/tree/master/gcpdb4u/templates/terraform-scripts/lpw)
and map to the per-team identities used by the configs:

- **Cloud Foundation** (`foundation/`) — org/folder level: `resourcemanager.projectCreator`,
  `billing.user`, `compute.xpnAdmin`, `resourcemanager.projectIamAdmin`,
  `serviceusage.serviceUsageAdmin`.
- **Network Engineering** (`host-network/`, `post-workspace/`) — on the **HOST** project:
  `compute.networkAdmin` (VPC, subnet, firewall, addresses, PSC forwarding rules),
  `compute.securityAdmin` (firewall), `dns.admin` (DNS zone/records + private-zone VPC
  bind), `resourcemanager.projectIamAdmin` (subnet IAM).
- **Cloud Security / KMS** (`service-cmek/`) — on the **SERVICE** project: `cloudkms.admin`
  (CMEK key + `setIamPolicy`), `resourcemanager.projectIamAdmin`.
- **Data / Databricks Platform** (`databricks-account/`) — Databricks **account admin**,
  plus `serviceusage.serviceUsageConsumer` + read on the **SERVICE** project.

> Use **predefined** roles, not a hand-built custom role: two permissions the deploy
> needs — `compute.forwardingRules.pscCreate` and `dns.networks.bindPrivateDNSZone` —
> cannot be added to a custom role (they are silently dropped), so a custom "creator"
> role perpetually 403s.

## Runner impersonation

Whoever invokes `terraform apply` (a person or a CI pipeline) impersonates the relevant
team's SA rather than acting as itself. Each runner needs
`roles/iam.serviceAccountTokenCreator` on the SA it impersonates — that role is what
grants the ability to mint tokens as the SA.
