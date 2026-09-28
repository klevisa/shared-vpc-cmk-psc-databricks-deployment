# Connecting Databricks to Dataproc Metastore (DPMS) — PoC template

**For:** Yahoo Mail POC1a · **date:** 2026-09-28 · classic clusters (not serverless)

Yahoo stands up a **DPMS instance in us-east4** (that setup is out of scope for this doc).
This template covers how a Databricks **classic cluster** connects to it, **how it
authenticates**, and the security guardrails that keep DPMS from becoming a back-door to
the us-east5 source data (threat-model ap10). Configs below are drawn from the live-verified
Yahoo DPMS interop sessions.

> **Not a UC foreign catalog.** Managed DPMS exposes only a **Thrift** endpoint (no
> JDBC-accessible backing DB), so **UC HMS Federation cannot target managed DPMS**. The
> connection is a **cluster-level Spark/Hive-metastore config**, not a Unity Catalog
> connection. (A cluster in `SINGLE_USER` mode can use UC *and* one DPMS side by side; a
> single cluster cannot bind two DPMS — the binding is fixed at boot.)

## Option A — Direct Thrift (default for a us-east4 DPMS in/peered to the Shared VPC)

Set these **at cluster creation** (not at runtime — the metastore client initializes at boot):

```
spark.hadoop.hive.metastore.uris     thrift://<DPMS_THRIFT_IP>:9083
spark.sql.hive.metastore.version     3.1.2        # MUST match the DPMS Hive version
spark.sql.hive.metastore.jars        maven
```

- The first HMS call downloads the Hive client jars from Maven (~1–2 min, one-time per cluster).
- `metastore.version` must equal the DPMS instance's Hive version exactly (3.1.2 / 3.1.3 — confirm on the instance).

### How auth works (Option A)
1. **Network** — the cluster must route to the DPMS Thrift endpoint on **9083** over the Analytics Shared VPC (same VPC, or non-transitive peering with a route). No public path.
2. **Identity** — grant the **cluster's attached Google SA** (`gcp_attributes.google_service_account`, the same compute-SA pattern used elsewhere) **`roles/metastore.metadataViewer`** (read-only) on the DPMS. Because it's a classic cluster with an attached SA, it authenticates via **ADC** — no key.

## Option B — DPMS Metadata Federation over gRPC (only if using the Federation endpoint)

If Yahoo uses **DPMS Federation** (a public Cloud Run **gRPC** endpoint, IAM-gated + TLS)
rather than a direct Thrift IP, Spark can't speak gRPC — run a **Thrift→gRPC hms-proxy**
via a cluster init script:

```
# init script (bare hms-proxy JAR):
#   proxy.mode=thrift  proxy.uri=<FEDERATION_CLOUD_RUN_GRPC_ENDPOINT>
#   thrift.listening.port=9083   (ADC auth, SSL upstream)
```
```
spark.hadoop.hive.metastore.uris          thrift://localhost:9083
spark.sql.hive.metastore.version          3.1.2
spark.sql.hive.metastore.jars             maven
spark.hadoop.hive.metastore.execute.setugi false
```

### Gotchas (Option B — all live-verified)
1. **`hive.metastore.execute.setugi=false`** — federation errors on the `set_ugi` handshake otherwise.
2. **`roles/metastore.metadataUser`** is required for the federation to forward to the backend — without it you get an opaque `UNKNOWN: Application error`, not `PERMISSION_DENIED`.
3. Use the **bare JAR** init script, not Google's Docker-based init action (that's Dataproc-only).
4. The federation endpoint is a **public Cloud Run gRPC URL** (IAM-gated, TLS), not a private VPC IP — reachable via the cluster's egress path.
5. hms-proxy JAR version doesn't matter (v0.0.46 and v0.0.70 behaved identically).
6. This proxy shim is **unsupported / DIY** — no first-party Databricks SLA.

## Security guardrails (ap10 — hold these regardless of option)

- **Read-only:** grant `roles/metastore.metadataViewer` (Option A) / `metadataUser` (Option B, for the forward) — **never `roles/metastore.editor`**, so a POC workload can't alter production metadata.
- **No us-east5 storage path:** the us-east4 DPMS's table locations must point at the **us-east4 landing buckets**, not the us-east5 source buckets. **No Databricks identity gets GCS access on the us-east5 source buckets** via a DPMS-returned location — that's the invariant that stops DPMS becoming a bypass of the STS copy + Unity Catalog governance.
- **Scope + observe:** scope the metadata read to the POC databases; enable **DPMS Data Access logs**; if the DPMS sits behind a perimeter, method-scope the ingress to metastore reads.

## Notes
- Reference profiles from the interop work (sandbox, not Yahoo prod): account `account-admin-fe-sandbox-gcp`, workspace `dpms-ws`; DPMS reached at `thrift://<ip>:9083`.
- This is a **classic-cluster** pattern. Serverless cannot attach a Google SA or reach a private Thrift endpoint, so serverless→DPMS would require the public Federation endpoint (Option B) plus an NCC/egress path — avoid for the POC.
