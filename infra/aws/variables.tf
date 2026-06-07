variable "app_name" {
  type    = string
  default = "hello-spring-boot-dsql"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Path to the Lambda deployment package built by `./gradlew lambdaZip`.
variable "lambda_zip_path" {
  type    = string
  default = "../../build/dist/function.zip"
}
