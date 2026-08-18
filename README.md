# Databricks workspace on a GCP Shared VPC (BYOVPC + PSC + CMEK)

A most-secure Databricks workspace on GCP: the network lives in a **host project**, the
workspace's compute and storage live in a **service project**, all traffic to Databricks
rides **Private Service Connect (PSC)**, and data is encrypted with a **customer-managed
key (CMEK)**.

The deployment is **split across teams** — each team runs one Terraform config with its
own least-privilege identity, wired together by output→input handoffs.

## Start here

- **[Deployment guide](workspace-setup-multi-team/README.md)** — which team owns each phase, why the order matters, the cross-team handoffs, step-by-step, and commands.
- **[Architecture](docs/architecture.md)** — the diagram, how PSC works, and how to test it.
- **[Databricks prerequisites](docs/databricks-prerequisites.md)** — the account, account admin, and metastore to set up before Phase 0.
- **[Catalog setup](catalog-setup/README.md)** — read-only + read-write Unity Catalog catalogs over GCS (with VPC-SC), the step after the workspace is up.
- **[Serverless setup](serverless-setup/README.md)** — bring serverless compute into the workspace (NCC + optional egress lockdown); ties into the catalog-setup VPC-SC ingress.

## Before you begin

The Terraform assumes three **Databricks-side** things already exist. They're set up once in
the Databricks account console / GCP Marketplace — not by these configs — and they feed
directly into Phase 3 (`databricks-account/`):

1. **A Databricks account** (via the GCP Marketplace subscription) → gives you `databricks_account_id`.
2. **An account admin** — the service account Phase 3 impersonates, registered as a Databricks
   account-admin user → this is Phase 3's `google_service_account_email`.
3. **A Unity Catalog metastore** in the workspace's region → gives you `metastore_id`.
   It may be pre-created and shared region-wide, but it is **required** — Phase 3 explicitly
   assigns the workspace to it.

Full walkthrough: **[Databricks prerequisites](docs/databricks-prerequisites.md)**.

## The configs

| Phase | Config | Team |
|---|---|---|
| 0 | [`workspace-setup-multi-team/foundation/`](workspace-setup-multi-team/foundation) | Cloud Foundation |
| 1 | [`workspace-setup-multi-team/host-network/`](workspace-setup-multi-team/host-network) | Network Engineering |
| 2 | [`workspace-setup-multi-team/service-cmek/`](workspace-setup-multi-team/service-cmek) | Cloud Security / KMS |
| 3 | [`workspace-setup-multi-team/databricks-account/`](workspace-setup-multi-team/databricks-account) | Data / Databricks Platform |
| 4 | [`workspace-setup-multi-team/post-workspace/`](workspace-setup-multi-team/post-workspace) | Network / Cloud IAM |

> **Illustrative values.** Project IDs, names, CIDRs, and the account ID in each
> `terraform.tfvars` are examples — replace them before applying. Every config is
> `terraform validate`-clean.

## After the workspace

Once the workspace is up, two further steps build on it (each its own config):

- **[`catalog-setup/`](catalog-setup/README.md)** — registers the Unity Catalog catalogs
  over GCS: a **read-only** catalog on the customer's existing data bucket and a
  **read-write** catalog on a PoC data bucket, with the VPC-SC ingress each needs.
- **[`serverless-setup/`](serverless-setup/README.md)** — brings **serverless compute**
  into the workspace via a Network Connectivity Config (and an optional egress network
  policy). Serverless reaches the catalogs through the same VPC-SC ingress that
  `catalog-setup` creates — the two steps are documented together there.
