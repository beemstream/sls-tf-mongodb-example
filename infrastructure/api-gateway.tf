resource "aws_api_gateway_rest_api" "service" {
  name = "tf-${var.name}"
}

resource "aws_api_gateway_method" "service_root" {
  rest_api_id   = aws_api_gateway_rest_api.service.id
  resource_id   = aws_api_gateway_rest_api.service.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "service" {
  rest_api_id = aws_api_gateway_rest_api.service.id
  parent_id   = aws_api_gateway_rest_api.service.root_resource_id
  path_part   = "settings"
}

resource "aws_api_gateway_method" "service" {
  count         = length(local.lambda_function_name)
  rest_api_id   = aws_api_gateway_rest_api.service.id
  resource_id   = aws_api_gateway_resource.service.id
  http_method   = local.lambdas_yml[local.lambda_function_name[count.index]].events[0].http.method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "service" {
  count       = length(local.lambda_function_name)
  rest_api_id = aws_api_gateway_rest_api.service.id
  resource_id = aws_api_gateway_method.service[count.index].resource_id
  http_method = aws_api_gateway_method.service[count.index].http_method

  integration_http_method = local.lambdas_yml[local.lambda_function_name[count.index]].events[0].http.method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.service[count.index].invoke_arn
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_permission" "apigw" {
  count         = length(local.lambda_function_name)
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.service[count.index].arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.service.id}/*/*"
}
