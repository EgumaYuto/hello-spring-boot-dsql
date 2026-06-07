terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # aws_dsql_cluster is available from provider v5.80+.
      version = ">= 5.80"
    }
  }

  # Local state on purpose: this is a throwaway sandbox for trying out Aurora DSQL.
  # Switch to an S3 backend if you want shared/remote state.
}

provider "aws" {
  region = var.region
}
