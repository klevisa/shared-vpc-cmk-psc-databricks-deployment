# Databricks prerequisites (before Stage 1)

> ← Back to the [PoC playbook](../README.md)

The workspace-setup Terraform provisions the GCP side of the workspace, but it **assumes** three
Databricks-side things already exist. These are **account-scoped, one-time** setups done in
the Databricks account console (and GCP Marketplace) — they are not created by any config,
and they precede Phase 0.

Each one produces a value you feed into **Phase 3** (`workspace-setup-multi-team/databricks-account/`):

| Prerequisite | Produces | Phase 3 input |
|---|---|---|
| 1. Databricks account | the account id | `databricks_account_id` |
| 2. Account admin | the SA that may call the account API | `google_service_account_email` |
| 3. Unity Catalog metastore | the metastore id | `metastore_id` (required) |

---

## 1. A Databricks account

On GCP, a Databricks account is created by subscribing to Databricks through the **GCP
Marketplace**. The subscription ties the Databricks account to your Google organization and
billing.

1. In the GCP console, go to **Marketplace** and subscribe to **Databricks** (the offer for
   your region/plan). This provisions a Databricks **account** reachable at
   `https://accounts.gcp.databricks.com`.
2. Sign in to the account console with the Google identity used for the subscription.
3. Find your **account id** — account console → the account menu (top right) / **Settings**;
   it's a UUID.

> **Produces:** `databricks_account_id` for Phase 3.

Do this once per organization. All workspaces (this one and any future ones) live under the
same account.

---

## 2. An account admin

Phase 3 authenticates to the account API by **impersonating the Data Platform automation
service account** (`google_service_account_email`). For those calls to be authorized, that
SA must be registered in Databricks as a **user with the account-admin role**.

1. **The first account admin** is the Google identity that set up the Marketplace
   subscription — that person can perform the steps below. (Nothing can grant the very first
   account admin; it's established at subscription. This is why it's a manual prerequisite.)
2. In the account console, go to **User management → Users → Add user**, and add the
   automation SA's email as the username.
   > **GCP specific:** a GCP service account federates to a Databricks **user**, not a
   > service principal — add it as a user, not an SP.
3. Grant that user the **Account admin** role.

> **Produces:** the account-admin identity used as Phase 3's `google_service_account_email`.

Once granted, Phase 3 runs unattended. Account admins also hold workspace-admin implicitly on
every workspace they create — which is why the deployment provisions no workspace admin. (For
a *delegated*, non-account-admin workspace admin, see Phase 5 in the
[deployment guide](../workspace-setup-multi-team/README.md).)

---

## 3. A Unity Catalog metastore

Unity Catalog organizes data under a **metastore** — an account-level object, **one per
region**. A workspace uses the metastore in **its** region, so one **must** exist in the
region you deploy into. It's a shared, region-wide object: it may already be created (reused
across every workspace in the region), but it is **not optional** — Phase 3 explicitly
assigns the workspace to it.

1. **Check** whether a metastore already exists in the workspace's region (account console →
   **Catalog** / **Data**). If one exists, just note its id.
2. **If none exists, create one** manually in the account console (**Catalog → Create
   metastore**), pinned to the region.
3. Copy the **metastore id**.
4. **Set the metastore admin — the metastore `owner` — to a group.** The metastore admin is a
   *role* (the owner), and it always carries full admin capability as Unity Catalog evolves —
   so make it a **group**, not an individual, and prefer an **IdP-synced group** of human
   governance owners: create the group + assign your admin user(s) **in your IdP** (Okta/Entra
   → SCIM), let it sync into the account, then set the metastore `owner` to it (account console,
   or `databricks metastores update <id> --owner <group>`). Automation identities do **not**
   go in this group — they get scoped `CREATE_*` grants in the catalog step instead.

> **Produces:** `metastore_id` (required) for Phase 3, which assigns the workspace to it with
> `databricks_metastore_assignment`.

Catalogs and their storage — a catalog backed by a customer GCS bucket — are set up in a
**later step of this repo**, after the workspace exists (the read-only catalog step). Here
you only need the region's metastore to exist and its id.

---

## How these map to Phase 3

In `workspace-setup-multi-team/databricks-account/terraform.tfvars`:

- `databricks_account_id` ← prerequisite 1
- `google_service_account_email` ← the SA made account admin in prerequisite 2
- `metastore_id` ← prerequisite 3 (required — the workspace is explicitly assigned to it)

Everything else Phase 3 needs is a handoff from Phases 0-2 (see the
[deployment guide](../workspace-setup-multi-team/README.md)).
