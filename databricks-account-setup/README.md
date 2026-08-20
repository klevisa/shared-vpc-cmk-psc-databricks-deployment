# 1. Databricks Account Setup

> ← Back to the [PoC playbook](../README.md)

Account-scoped, one-time setup done in the **GCP Marketplace**, the **Databricks account
console**, and your **IdP** — before the workspace (Phase 2). Two steps:

- **1.1 Databricks Account Setup** — the account, its admins, and the regional metastore.
- **1.2 IdP Sync** — sync your users and groups into the account, then set the metastore owner.

**Owner:** Databricks + GCP Billing Admin (1.1); Databricks + IdP Admin (1.2).

---

## 1.1 · Databricks Account Setup

Produces the things the workspace step (2.4) consumes:

| Produces | Step 2.4 input |
|---|---|
| Databricks account | `databricks_account_id` |
| Account-admin automation SA | `databricks_account_admin_sa` |
| Unity Catalog metastore (regional) | `metastore_id` (required) |

**a. A Databricks account.** On GCP, subscribe to Databricks through the **GCP Marketplace**;
the subscription ties the account to your Google organization and billing and provisions the
account at `https://accounts.gcp.databricks.com`. Sign in with the subscribing identity and
note the **account id** (a UUID, under the account menu / Settings). Do this once per
organization — all workspaces live under the same account.

**b. Two account admins.** There are two, with different jobs:

1. **The human account admin** — the Google identity that set up the Marketplace subscription.
   Nothing can grant the *first* admin (it's established at subscription), which is why it's a
   manual prerequisite. This person performs the steps in this phase.
2. **`databricks_account_admin_sa`** — a **GCP service account** that the human admin registers
   as a Databricks **account-admin user**, used to *automate* workspace creation (step 2.4
   impersonates it to call the account API). On GCP a service account federates to a Databricks
   **user**, not a service principal — so in the account console → **User management → Users →
   Add user**, add the SA's email, then grant it the **Account admin** role.

Account admins hold workspace-admin implicitly on every workspace they create, so no separate
workspace admin is required. A *delegated*, non-account-admin workspace admin can be assigned by
the Data Platform team once a group has synced (1.2) — a one-line account-API step.

**c. A Unity Catalog metastore.** Unity Catalog organizes data under a **metastore** — an
account-level object, **one per region**. One **must** exist in the region you deploy into (it
may be pre-created and shared region-wide); step 2.4 explicitly assigns the workspace to it.
- Check the account console (**Catalog**) for an existing metastore in the region; if none,
  create one pinned to the region, and copy its **metastore id**.
- **Leave the metastore owner for after IdP sync (1.2).** The owner should be an IdP-synced
  human governance **group**, and no groups exist in the account yet — so the metastore just
  needs to *exist* here; its owner is set at the end of 1.2.
- **Enable the system-table schemas** on the metastore (account/metastore admin) — the
  production baseline for cost, governance, and ops. `billing` is on by default; enable:
  ```bash
  for s in access lakeflow compute query data_classification tags storage; do
    databricks system-schemas enable <metastore-id> "$s"
  done
  ```
  Enabling only makes the tables *exist*; access is granted **separately** (`USE CATALOG` on
  `system` + `USE SCHEMA` + `SELECT` per schema) and should be **gated** — they hold sensitive
  operational/audit data. (What each schema is for: `access` = audit + lineage, `lakeflow` =
  job/pipeline runs, `compute` = clusters/warehouses, `query` = SQL history,
  `data_classification` = PII scan results, `tags` = governed tags, `storage` = storage ops.)

Catalogs and their storage are set up later, in **Phase 3 (Data Access)** — here you only need
the region's metastore to exist and its id.

---

## 1.2 · IdP Sync

Get your identities and groups into the Databricks account so they're available for the
metastore-owner group, the delegated workspace admin, and the data/benchmark grants.

1. Configure **SCIM** provisioning in your IdP (Okta/Entra) so **users and groups** sync into
   the Databricks **account** (account-scoped, one-time). Optionally configure **SSO / unified
   login**. → [Sync users and groups from your identity provider using SCIM](https://docs.databricks.com/gcp/en/admin/users-groups/scim/)
2. Reference synced groups read-only wherever they're used (metastore owner, workspace `ADMIN`,
   UC grants) — don't manage the synced objects as Terraform resources.

**Owner:** Databricks account admin (enable SCIM, issue the token) + IdP admin (configure the
provisioning app). **Produces:** your identities and groups in the Databricks account.

There's no bootstrap risk: until SCIM is live, the human account admin from 1.1 is already a
full workspace admin.

### After sync — set the metastore owner

Now that a governance **group** exists in the account, set the metastore's **owner** to it. The
metastore admin is a *role* — the owner — that carries full admin capability as Unity Catalog
evolves, so it belongs to an **IdP-synced human group**, never an individual or an automation
SA. Set it in the account console (**Catalog → the metastore → Owner**) or via
`databricks metastores update <metastore-id> --owner <group>`. Automation identities get scoped
`CREATE_*` grants in Phase 3 instead — they don't go in this group.
