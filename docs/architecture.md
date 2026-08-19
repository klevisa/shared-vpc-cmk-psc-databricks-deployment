# Architecture

> ← Back to the [PoC playbook](../README.md) · detail for [Stage 1](../workspace-setup-multi-team/README.md)

Three domains: the **host** project (network), the **service** project (Databricks
compute + CMEK), and the **Databricks** control plane (its own projects). PSC is the
private wire between your VPC and Databricks — two endpoints: a **frontend** (UI/REST)
and a **backend** (secure cluster-to-control-plane relay).

```mermaid
flowchart LR
    USER["Admin / analyst<br/>browser + REST"]

    subgraph HOST["HOST project: Shared VPC network"]
        direction TB
        DNS["Private DNS zone<br/>gcp.databricks.com<br/>resolves names to private IPs"]
        subgraph NODE["node subnet 10.10.0.0/24"]
            VM["Workspace cluster VMs (NPIP)<br/>owned by SERVICE project,<br/>placed here via networkUser"]
        end
        subgraph PE["PSC subnet 10.10.1.0/28"]
            FE["Frontend PSC endpoint<br/>fwd rule + internal IP"]
            BE["Backend PSC endpoint<br/>fwd rule + internal IP"]
        end
        FW["Firewall<br/>internal + node to psc"]
    end

    subgraph SVC["SERVICE project: Databricks compute and data"]
        direction TB
        WSSA["Workspace SA<br/>db-ID@prod-gcp-REGION<br/>launches cluster VMs"]
        KMS["CMEK key"]
        DATA["Workspace GCE disks + GCS<br/>CMEK-encrypted"]
    end

    subgraph DBX["Databricks: owned projects"]
        direction TB
        PLPROXY["plproxy service attachment<br/>FRONTEND: UI / REST"]
        NGROK["ngrok service attachment<br/>BACKEND: cluster relay"]
        ACCT["Account API<br/>accounts.gcp.databricks.com"]
    end

    USER -->|"workspace URL, 443"| FE
    VM -->|"resolve workspace host"| DNS
    DNS -.->|"private IP"| FE
    DNS -.->|"private IP"| BE
    VM -->|"REST / artifacts, 443"| FE
    VM -->|"secure cluster relay, 6666"| BE
    FE ==>|"PSC"| PLPROXY
    BE ==>|"PSC"| NGROK
    KMS -->|"encrypts"| DATA
    WSSA -.->|"networkUser on node subnet"| NODE
    ACCT -.->|"provisions"| SVC
```

**How PSC works here:** your VPC creates two PSC *endpoints* (consumer side); each
targets a Databricks *service attachment* (producer side). The **frontend** carries
UI/REST; the **backend** carries the secure cluster connectivity relay on `6666`. The
private DNS zone points the workspace hostnames at the private endpoint IPs, so from
inside the VPC everything resolves to `10.10.x` and never leaves the private path.

## What lives where

| Concern | Project | Resources | Phase |
|---|---|---|---|
| Foundation | **Host + Service** | service project, API enablement, Shared VPC host+attach, GCS service agent | 0 |
| Network | **Host** | VPC, node + psc subnets, firewall, router/NAT, PSC IPs + forwarding rules, private DNS zone | 1 |
| CMEK | **Service** | CMEK key + storage-agent grants | 2 |
| Account objects | **Account** | 2 VPC endpoints, private access settings, network config, CMEK registration, workspace | 3 |
| Cross-project IAM + DNS records | **Host** | `compute.networkUser` for the workspace SA + 4 A-records | 4 |

## Testing PSC

- **Backend (relay):** launch a cluster. Reaching `RUNNING` proves the relay path
  (`tunnel.<region>` → backend IP:6666) end to end — a NPIP node in your VPC reached the
  control plane over PSC.
- **Frontend / private DNS:** from a VM inside the host VPC (a bastion, a CI runner
  peered to the network, or a temporary instance in the node subnet):
  - `nslookup <workspace-url>` returns the **frontend PSC IP** (`10.10.1.x`), not a public IP;
  - `curl -sI https://<workspace-url>` returns a Databricks response header (e.g.
    `x-databricks-org-id`), confirming the private frontend serves the workspace.
