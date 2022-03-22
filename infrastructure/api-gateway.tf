resource "aws_api_gateway_rest_api" "service" {
  name = "tf-${var.name}"
}

resource "aws_api_gateway_deployment" "service_deployment" {
  rest_api_id = aws_api_gateway_rest_api.service.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.service,
      aws_api_gateway_method.service,
      aws_api_gateway_integration.service,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_account" "service_account" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

resource "aws_iam_role" "cloudwatch" {
  name = "api_gateway_cloudwatch_global"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "default"
  role = aws_iam_role.cloudwatch.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_api_gateway_stage" "stages" {
  deployment_id = aws_api_gateway_deployment.service_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.service.id
  stage_name    = "uat"
}

resource "aws_api_gateway_method_settings" "service_settings" {
  rest_api_id = aws_api_gateway_rest_api.service.id
  stage_name  = aws_api_gateway_stage.stages.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    data_trace_enabled     = true
    logging_level          = "INFO"
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
  }
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
