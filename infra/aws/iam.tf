data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.app_name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Basic CloudWatch Logs permissions.
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Aurora DSQL IAM auth: allow connecting as the admin database role.
# This replaces the password/Secrets Manager approach entirely.
data "aws_iam_policy_document" "dsql_connect" {
  statement {
    actions   = ["dsql:DbConnectAdmin"]
    resources = [aws_dsql_cluster.main.arn]
  }
}

resource "aws_iam_role_policy" "dsql_connect" {
  name   = "${var.app_name}-dsql-connect"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.dsql_connect.json
}
