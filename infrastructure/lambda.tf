resource "aws_s3_bucket_object" "zipped_lambda" {
  count  = length(local.lambda_function_name)
  bucket = "${aws_s3_bucket.lambda_storage.bucket}"
  key    = "hello.zip"
  source = "../.serverless/hello.zip"
  etag   = filemd5("../.serverless/hello.zip")
}

resource "aws_s3_bucket" "lambda_storage" {
  bucket = "tf-${var.name}-storage"
}

resource "aws_lambda_function" "service" {
  count         = length(local.lambda_function_name)
  function_name = "tf-${local.lambda_function_name[count.index]}"
  memory_size   = local.lambdas_yml[local.lambda_function_name[count.index]].memory_size

  s3_bucket = "${aws_s3_bucket.lambda_storage.bucket}"
  s3_key    = "${aws_s3_bucket_object.zipped_lambda[count.index].key}"

  handler = "src/functions/${local.lambda_function_name[count.index]}/handler.main"
  runtime = "nodejs14.x"
  role    = "${aws_iam_role.service.arn}"

  vpc_config {
    subnet_ids         = module.vpc.public_subnets
    security_group_ids = ["${aws_security_group.service.id}"]
  }

  environment {
    variables = {
      DB_CONNECTION_STRING = "mongodb://${aws_docdb_cluster.service.master_username}:${aws_docdb_cluster.service.master_password}@${aws_docdb_cluster.service.endpoint}:${aws_docdb_cluster.service.port}"
    }
  }
}

resource "aws_iam_role" "service" {
  name = "tf-${var.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "service" {
  name = "tf-${var.name}"
  role = "${aws_iam_role.service.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*",
        "ec2:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "service" {
  name = "tf-${var.name}"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "service" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "${aws_iam_policy.service.arn}"
}
