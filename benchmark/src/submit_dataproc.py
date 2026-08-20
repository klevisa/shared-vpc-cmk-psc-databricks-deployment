"""Submit the benchmark PySpark file to Dataproc on an EPHEMERAL, run_id-labeled cluster.

Run as bench-runner. Creates a short-lived Dataproc cluster — hardware matched to the
Databricks job clusters, labeled project/engine=dataproc/run_id, auto-deleted when idle —
submits the same PySpark file to it, grants the data-collector jobs.get on that job, and
records the run. Putting run_id on the CLUSTER is what lands it on the VM billing rows
(Dataproc job labels don't reach the VMs), giving clean per-run VM-cost attribution.

Network: calls dataproc.googleapis.com, reachable from classic Databricks compute over
Private Google Access. Illustrative: install google-cloud-dataproc.
"""
import argparse
import datetime as dt
import json
import uuid

from google.cloud import dataproc_v1
from google.iam.v1 import policy_pb2
from google.oauth2 import service_account
from pyspark.sql import SparkSession


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gcp-project", required=True)
    ap.add_argument("--dataproc-region", required=True)
    ap.add_argument("--pyspark-uri", required=True, help="gs:// path to the benchmark file")
    ap.add_argument("--job-name", required=True)
    ap.add_argument("--project-tag", default="dataproc-vs-photon")
    # Match the Databricks job clusters for a fair comparison.
    ap.add_argument("--master-machine-type", required=True)
    ap.add_argument("--worker-machine-type", required=True)
    ap.add_argument("--num-workers", type=int, required=True)
    ap.add_argument("--idle-delete-ttl-seconds", type=int, default=600, help="auto-delete after idle")
    ap.add_argument("--data-collector-sa", required=True, help="SA to grant jobs.get on this job")
    ap.add_argument("--jobs-get-role", required=True, help="custom role with dataproc.jobs.get")
    ap.add_argument("--runs-table", default="analytics.benchmark.dataproc_runs")
    ap.add_argument("--secret-scope", default="benchmark")
    ap.add_argument("--secret-key", default="gcp_dataproc_runner_key")
    args = ap.parse_args()

    spark = SparkSession.builder.getOrCreate()
    from pyspark.dbutils import DBUtils

    dbutils = DBUtils(spark)
    info = json.loads(dbutils.secrets.get(args.secret_scope, args.secret_key))
    creds = service_account.Credentials.from_service_account_info(info)

    suffix = uuid.uuid4().hex[:8]
    run_id = f"{args.job_name}-dataproc-{suffix}"  # label value + Dataproc job id
    cluster_name = f"bench-{suffix}"               # cluster names: lowercase/digits/hyphen only
    labels = {"project": args.project_tag, "engine": "dataproc", "run_id": run_id}
    opts = {"api_endpoint": f"{args.dataproc_region}-dataproc.googleapis.com:443"}

    # 1) Create the ephemeral, labeled cluster (run_id on the CLUSTER -> on the VM billing
    #    rows); it auto-deletes after idle so we don't pay for it or have to tear it down.
    cc = dataproc_v1.ClusterControllerClient(credentials=creds, client_options=opts)
    cluster = {
        "project_id": args.gcp_project,
        "cluster_name": cluster_name,
        "labels": labels,
        "config": {
            "master_config": {"num_instances": 1, "machine_type_uri": args.master_machine_type},
            "worker_config": {"num_instances": args.num_workers, "machine_type_uri": args.worker_machine_type},
            "lifecycle_config": {"idle_delete_ttl": {"seconds": args.idle_delete_ttl_seconds}},
        },
    }
    cc.create_cluster(
        request={"project_id": args.gcp_project, "region": args.dataproc_region, "cluster": cluster}
    ).result()  # wait until the cluster is up

    # 2) Submit the same PySpark file to it (job id = run_id).
    jc = dataproc_v1.JobControllerClient(credentials=creds, client_options=opts)
    job = {
        "reference": {"job_id": run_id},
        "placement": {"cluster_name": cluster_name},
        "labels": labels,
        "pyspark_job": {"main_python_file_uri": args.pyspark_uri},
    }
    jc.submit_job(project_id=args.gcp_project, region=args.dataproc_region, job=job)

    # 3) Grant the data-collector jobs.get on THIS job only (per-job IAM).
    resource = f"projects/{args.gcp_project}/regions/{args.dataproc_region}/jobs/{run_id}"
    policy = jc.get_iam_policy(request={"resource": resource})
    policy.bindings.append(
        policy_pb2.Binding(role=args.jobs_get_role, members=[f"serviceAccount:{args.data_collector_sa}"])
    )
    jc.set_iam_policy(request={"resource": resource, "policy": policy})

    # 4) Record the run so collect_dataproc picks it up automatically.
    spark.createDataFrame(
        [(run_id, args.job_name, "dataproc", dt.datetime.utcnow())],
        schema="run_id string, job_name string, engine string, submitted_at timestamp",
    ).write.mode("append").saveAsTable(args.runs_table)

    print(f"submit_dataproc: cluster={cluster_name} run_id={run_id} (auto-deletes after {args.idle_delete_ttl_seconds}s idle)")


if __name__ == "__main__":
    main()
