resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.app_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "app" {
  function_name = var.app_name
  role          = aws_iam_role.lambda.arn
  runtime       = "java21"
  # Spring Boot runs inside Lambda via aws-serverless-java-container. The generic
  # handler locates the @SpringBootApplication class from the MAIN_CLASS env var.
  handler = "com.amazonaws.serverless.proxy.spring.SpringDelegatingLambdaContainerHandler"

  filename         = var.lambda_zip_path
  source_code_hash = fileexists(var.lambda_zip_path) ? filebase64sha256(var.lambda_zip_path) : null

  # Spring Boot needs headroom; more memory also means more vCPU -> faster cold start.
  memory_size = 1024
  # Generous timeout to absorb the JVM/Spring cold start (+ Flyway on first boot).
  timeout = 60

  environment {
    variables = {
      MAIN_CLASS             = "org.example.MyApplication"
      SPRING_PROFILES_ACTIVE = "dsql"
      SPRING_DATASOURCE_URL  = local.dsql_jdbc_url
      # Trim JIT work to shave a little off cold starts.
      JAVA_TOOL_OPTIONS = "-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda,
  ]
}

# Public Function URL so you can hit the app with plain curl. Lock this down
# (AWS_IAM auth) for anything beyond a sandbox.
resource "aws_lambda_function_url" "app" {
  function_name      = aws_lambda_function.app.function_name
  authorization_type = "NONE"
}
