locals {
  lambdas_yml = yamldecode(file("../serverless.yaml")).functions
  lambda_function_name = keys(local.lambdas_yml)
}
