output "function_url" {
  description = "Public URL of the Lambda function."
  value       = aws_lambda_function_url.app.function_url
}

output "dsql_cluster_identifier" {
  value = aws_dsql_cluster.main.identifier
}

output "dsql_endpoint" {
  description = "Aurora DSQL connection endpoint (PostgreSQL, port 5432, IAM auth)."
  value       = local.dsql_endpoint
}

output "dsql_jdbc_url" {
  value = local.dsql_jdbc_url
}
