# Custom IAM Roles — Security Review Reference

One-page sign-off sheet for the custom GCP IAM roles this playbook defines, so reviewers don't
have to read Terraform. Every permission list below is transcribed verbatim from the role
definitions in this repo (re-verify against the `.tf` on review).
The five **core LPW roles** are the ones open item 3 asks Yahoo to review; they match the
Databricks published v2 lists (re-verified against
[permissions](https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/permissions)
and [sa-permissions](https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/sa-permissions)).

## How to read this
- **Bound to** = the principal that gets the role. **Scope** = the resource/condition on the binding (containment lives on the binding, not the role).
- All operator/agent grants carry a `request.time < poc_expiry` condition; creator roles are also count-gated and removed at step 2.9.

---

## Core LPW roles (open item 3 — match Databricks v2)

### 1. `lpw.databricks.project.role.v2` — workspace SA project role
- **Project:** service · **Bound to:** workspace SA · **Scope:** project-wide, `poc_expiry` · **File:** `workspace-sa-roles/roles.tf`
- **Risk:** Low — read/list/get only; no mutation, no IAM, no data plane.
- **Vendor match:** exact minus the three identity permissions (`actAs`/`getAccessToken`/`getOpenIdToken`), which the vendor says may be scoped per-SA (I1 accepted, PR #15). `actAs` is instead a resource-scoped binding on the node SA.
- **15 permissions:** `compute.disks.list` · `compute.globalOperations.list` · `compute.instances.list` · `compute.regionOperations.list` · `compute.regions.get` · `compute.reservations.get` · `compute.reservations.list` · `compute.spotAssistants.get` · `compute.zoneOperations.list` · `compute.zones.get` · `compute.zones.list` · `resourcemanager.projects.get` · `serviceusage.quotas.get` · `serviceusage.services.list` · `storage.buckets.list`

### 2. `lpw.databricks.resource.role.v2` — workspace SA resource role
- **Project:** service · **Bound to:** workspace SA · **Scope:** project-wide **but conditioned** to resources named with both `databricks` and the workspace id, AND `poc_expiry` · **File:** `workspace-sa-roles/roles.tf`
- **Risk:** Medium — the only powerful role: create/delete/use of disks, instances, buckets, objects, plus `instances.setServiceAccount`/`setMetadata` and `buckets.setIamPolicy`. **All three are vendor-required**; the role isn't bounded internally — the **binding condition** is the containment. (A tighter `startsWith` condition was tried and reverted: instance/disk naming is undocumented and it risks breaking cluster launch. Residual accepted with `SetIamPolicy` monitoring.)
- **Vendor match:** exact against the vendor compute + storage set.
- **35 permissions:** `compute.disks.{create,delete,get,resize,setLabels,update,use,useReadOnly}` · `compute.instances.{attachDisk,create,delete,detachDisk,get,getGuestAttributes,getSerialPortOutput,setLabels,setMetadata,setServiceAccount,setTags,update}` · `storage.buckets.{create,delete,get,getIamPolicy,setIamPolicy,update}` · `storage.multipartUploads.{abort,create,list,listParts}` · `storage.objects.{create,delete,get,list,update}`

### 3. `lpw.databricks.network.role.v2` — workspace SA network role
- **Project:** host · **Bound to:** workspace SA · **Scope:** node subnet only, `poc_expiry` · **File:** `post-workspace/iam.tf`
- **Risk:** Low — cannot alter routes, firewalls or peering.
- **Vendor match:** exact. Least-privilege replacement for predefined `roles/compute.networkUser`.
- **2 permissions:** `compute.subnetworks.get` · `compute.subnetworks.use`

### 4. `lpw.databricks.workspace.creator.host.v2` — creator SA (host)
- **Project:** host · **Bound to:** workspace-creator SA · **Scope:** creation-only, count-gated + `poc_expiry`, removed at 2.9 · **File:** `network/creator-roles.tf`
- **Risk:** Low — read-only host-network validation; discloses reads, changes nothing.
- **Vendor match:** exact.
- **11 permissions:** `compute.forwardingRules.get` · `compute.forwardingRules.list` · `compute.networks.get` · `compute.projects.get` · `compute.subnetworks.get` · `compute.subnetworks.getIamPolicy` · `iam.roles.get` · `resourcemanager.projects.get` · `resourcemanager.projects.getIamPolicy` · `serviceusage.services.get` · `serviceusage.services.list`

### 5. `lpw.databricks.workspace.creator.service.v2` — creator SA (service)
- **Project:** service · **Bound to:** workspace-creator SA · **Scope:** creation-only, count-gated + `poc_expiry`, removed at 2.9 · **File:** `service-project/creator-roles.tf`
- **Risk:** Low — read-only settings validation; includes two IAM-policy reads (minor info disclosure), no mutation.
- **Vendor match:** exact.
- **9 permissions:** `cloudkms.cryptoKeys.getIamPolicy` · `compute.projects.get` · `iam.roles.get` · `iam.serviceAccounts.get` · `iam.serviceAccounts.getIamPolicy` · `resourcemanager.projects.get` · `resourcemanager.projects.getIamPolicy` · `serviceusage.services.get` · `serviceusage.services.list`

---

## Supporting roles (added after the original review)

### 6. `lpw.databricks.network.agent.v2` — compute service agent (PR #20)
- **Project:** host · **Bound to:** the service project's Compute Engine service agent · **Scope:** node subnet · **File:** `network/iam.tf`
- **Risk:** Low — replaces the broad predefined `roles/compute.networkUser` for the agent. **Omits `compute.subnetworks.useExternalIp`** (clusters are private); add it back only if external IPs are ever needed.
- **2 permissions:** `compute.subnetworks.get` · `compute.subnetworks.use`

### 7. `benchmarkDataproc` — Composer/Airflow SA (PR #21)
- **Project:** service/Dataproc · **Bound to:** Composer SA · **Scope:** project, `poc_expiry` · **File:** `benchmark-prereqs/airflow-copy.tf`
- **Risk:** Low-Medium — deliberately **not** `roles/dataproc.editor`; create/observe/label the ephemeral benchmark cluster + read job status only.
- **5 permissions:** `dataproc.clusters.create` · `dataproc.clusters.get` · `dataproc.clusters.delete` · `dataproc.clusters.setLabels` · `dataproc.jobs.get`

### 8. `benchmarkStorageTransfer` — Composer/Airflow SA (PR #21)
- **Project:** copy-target · **Bound to:** Composer SA · **Scope:** project, `poc_expiry` · **File:** `benchmark-prereqs/airflow-copy.tf`
- **Risk:** Low — deliberately **not** `roles/storagetransfer.admin`; create/run/observe the one-time source→poc_bucket transfer only.
- **5 permissions:** `storagetransfer.jobs.create` · `storagetransfer.jobs.get` · `storagetransfer.jobs.run` · `storagetransfer.operations.get` · `storagetransfer.operations.list`

---

## Reviewer notes
- **No role grants project Owner, Editor, or any `setIamPolicy` beyond `storage.buckets.setIamPolicy`** (role 2, vendor-required, workspace-condition-bounded).
- **No role grants `iam.serviceAccounts.actAs` at the project level** — `actAs` is a separate resource-scoped binding on the dedicated node SA (and, for the benchmark, the collector SA).
- **The predefined roles the standing team SAs hold** (`projectCreator`, `xpnAdmin`, `networkAdmin`, `cloudkms.admin`, `policyAdmin`, etc.) are **not defined here** — they're Yahoo's standing grants, documented in the variable descriptions and covered by the customer action list (scope to a PoC folder + time-box).
