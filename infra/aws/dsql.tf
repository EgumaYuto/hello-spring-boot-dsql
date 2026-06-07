resource "aws_dsql_cluster" "main" {
  # No deletion protection: this is a sandbox we want to tear down freely.
  deletion_protection_enabled = false

  tags = {
    Name = var.app_name
  }
}

locals {
  # Aurora DSQL connection endpoint follows a fixed hostname convention.
  dsql_endpoint = "${aws_dsql_cluster.main.identifier}.dsql.${var.region}.on.aws"

  # JDBC URL for the Aurora DSQL connector (handles IAM token auth transparently).
  dsql_jdbc_url = "jdbc:aws-dsql:postgresql://${local.dsql_endpoint}:5432/postgres"
}
