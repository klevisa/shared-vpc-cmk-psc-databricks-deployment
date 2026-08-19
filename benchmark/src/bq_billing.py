"""Shared helper: GCP-side cost from the scoped BigQuery billing view.

Both collectors (Databricks + Dataproc) get their VM cost from the SAME authorized view.
The view is scoped by the billing team to only the benchmark rows and exposes a clean
shape: run_id, platform, engine, cost (see prerequisites.md for the view definition).
The service principal only ever sees that view — not the full billing export.
"""
import json

from google.cloud import bigquery
from google.oauth2 import service_account


def gcp_credentials(dbutils, secret_scope, secret_key):
    """Build GCP credentials from the SP's SA-key JSON stored in a Databricks secret."""
    info = json.loads(dbutils.secrets.get(secret_scope, secret_key))
    return service_account.Credentials.from_service_account_info(info)


def vm_cost_by_run(creds, bq_view, platform):
    """Return {run_id: gcp_vm_cost_usd} for the given platform from the billing view."""
    client = bigquery.Client(credentials=creds, project=creds.project_id)
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
