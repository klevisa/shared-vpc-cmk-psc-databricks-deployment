# Databricks workspace on a GCP Shared VPC (BYOVPC + PSC + CMEK)

A most-secure Databricks workspace on GCP: the network lives in a **host project**, the
workspace's compute and storage live in a **service project**, all traffic to Databricks
rides **Private Service Connect (PSC)**, and data is encrypted with a **customer-managed
key (CMEK)**.

The deployment is **split across teams** — each team runs one Terraform config with its
own least-privilege identity, wired together by output→input handoffs.

## Start here

- **[Deployment guide](multi-team/README.md)** — which team owns each phase, why the order matters, the cross-team handoffs, step-by-step, and commands.
- **[Architecture](docs/architecture.md)** — the diagram, how PSC works, and how to test it.
- **[Databricks prerequisites](docs/databricks-prerequisites.md)** — the account, account admin, and metastore to set up before Phase 0.

## Before you begin

The Terraform assumes three **Databricks-side** things already exist. They're set up once in
the Databricks account console / GCP Marketplace — not by these configs — and they feed
directly into Phase 3 (`databricks-account/`):

1. **A Databricks account** (via the GCP Marketplace subscription) → gives you `databricks_account_id`.
2. **An account admin** — the service account Phase 3 impersonates, registered as a Databricks
   account-admin user → this is Phase 3's `google_service_account_email`.
3. **A Unity Catalog metastore** in the workspace's region → gives you `metastore_id`
   (optional; leave empty to rely on auto-assignment).

Full walkthrough: **[Databricks prerequisites](docs/databricks-prerequisites.md)**.

## The configs

| Phase | Config | Team |
|---|---|---|
| 0 | [`multi-team/foundation/`](multi-team/foundation) | Cloud Foundation |
| 1 | [`multi-team/host-network/`](multi-team/host-network) | Network Engineering |
| 2 | [`multi-team/service-cmek/`](multi-team/service-cmek) | Cloud Security / KMS |
| 3 | [`multi-team/databricks-account/`](multi-team/databricks-account) | Data / Databricks Platform |
| 4 | [`multi-team/post-workspace/`](multi-team/post-workspace) | Network / Cloud IAM |

> **Illustrative values.** Project IDs, names, CIDRs, and the account ID in each
> `terraform.tfvars` are examples — replace them before applying. Every config is
> `terraform validate`-clean.
