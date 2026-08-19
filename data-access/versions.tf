terraform {
  required_version = ">= 1.5.0"
  required_providers {
    databricks = { source = "databricks/databricks", version = ">= 1.50.0" }
    google     = { source = "hashicorp/google", version = ">= 5.0.0" }
  }
}
