# Benchmark prerequisites (Terraform)

> ← [Benchmark](../benchmark/README.md) · [PoC playbook](../README.md)

Codifies the grants that `benchmark/prerequisites.md` §3–5 used to create by hand
(`gcloud`/console), so they land in Terraform state — drift detection, `poc_expiry`
auto-expiry, and `terraform destroy` at teardown — and appear in the least-privilege
identity map. Runs after the workspace + data-access phases exist.

## What it creates / grants

| Resource | Scope | Best-practice applied |
|---|---|---|
| Keyless collector SA + BQ reads | `dataViewer` on the **authorized view** + `jobUser` on the billing project | keyless (ADC on the cluster); `jobUser` time-boxed; view-only, never the raw export |
| Composer (Airflow) SA | custom **Dataproc** role (not `dataproc.editor`), source read (prefix-scoped), `poc_bucket` write, custom **STS** role | custom roles; `poc_expiry`; prefix + bucket scoping |
| STS service agent | source read (prefix) + `poc_bucket` write (`objectUser`, not `objectAdmin`) | `poc_expiry`; optional CMEK decrypt only if the source is CMEK |
| `poc_bucket` | created here; `force_destroy` (copied input) | uniform bucket-level access (enables IAM conditions) |
| STS VPC-SC ingress rule | STS agent, pinned projects, copy methods only | **only needed if the source is inside a perimeter**; remove otherwise |
| SP Unity Catalog grants | `bench-runner` / `-collector` / `-analyst` (ported from `sql/grants.sql`) | additive `databricks_grant` (no clobbering); least-privilege per SP |

## Decide during the PoC (placeholders until then)

- `source_object_prefix` — the real input prefix (sample `mail-data/`).
- `sts_protected_resources` / `perimeter_name` — **only if** the source bucket is inside a
  VPC-SC perimeter and STS is the copy mechanism. If not, delete the ingress rule.
- `source_cmek_key` — only if the source bucket uses a customer-managed key.

## Providers / who runs it

Aliased impersonation providers (see `providers.tf`), one per owning team; the runner needs
`roles/iam.serviceAccountTokenCreator` on each. The `uc_admin` Databricks provider must be a
**metastore admin** (to grant on `analytics`, `source_data_ro`, `system`).

## Run

```bash
export TF_VAR_uc_grantor_client_secret=...
terraform init && terraform apply -var-file=terraform.tfvars
```

Feed the `collector_sa_email` output into the benchmark bundle's `collector_sa` variable.

## Teardown

`terraform destroy` removes every grant, the `poc_bucket`, the custom roles, and the STS
ingress rule. Replaces the manual cleanup that teardown T1/T7 previously listed.
