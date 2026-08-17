# Databricks workspace on a GCP Shared VPC (BYOVPC + PSC + CMEK)

A most-secure Databricks workspace on GCP: the network lives in a **host project**, the
workspace's compute and storage live in a **service project**, all traffic to Databricks
rides **Private Service Connect (PSC)**, and data is encrypted with a **customer-managed
key (CMEK)**.

The deployment is **split across teams** — each team runs one Terraform config with its
own least-privilege identity, wired together by output→input handoffs.

## Start here

- **[Deployment guide](multi-team/README.md)** — the configs, run order, handoffs, and commands.
- **[Runbook](docs/multi-team-runbook.md)** — which team owns each phase and why the order matters.
- **[Architecture](docs/architecture.md)** — the diagram, how PSC works, and how to test it.
- **[Identity & access](docs/identity-and-access.md)** — the admin model, automation identities, and least-privilege roles.

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
