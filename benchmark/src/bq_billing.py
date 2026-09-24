"""Shared helper: GCP-side cost from the scoped BigQuery billing view.

Both platforms' VM cost comes from the SAME authorized view, scoped by the billing team to
the benchmark rows (run_id, platform, engine, cost — see prerequisites.md). Auth is KEYLESS:
the collector job cluster runs as the attached collector SA and the code uses Application
Default Credentials (ADC). No service-account key, no secret scope.
"""
from google.cloud import bigquery


def vm_cost_by_run(bq_view, platform, project=None):
    """Return {run_id: gcp_vm_cost_usd} for the given platform from the billing view.

    Credentials come from ADC (the cluster's attached collector SA) — none are passed in.
    """
    client = bigquery.Client(project=project)
    sql = f"""
        SELECT run_id, SUM(cost) AS gcp_vm_cost_usd
        FROM `{bq_view}`
        WHERE platform = @platform
        GROUP BY run_id
    """
    job = client.query(
        sql,
        job_config=bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("platform", "STRING", platform)]
        ),
    )
    return {row["run_id"]: float(row["gcp_vm_cost_usd"]) for row in job.result()}
