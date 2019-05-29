provider "archive" {}

data "archive_file" "zip" {
  type        = "zip"
  source_file = "batch.py"
  output_path = "batch.zip"
}

resource "aws_cloudwatch_event_rule" "cron" {
  name                = "cron"
  description         = "each day cron"
  schedule_expression = "rate(1440 minutes)"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

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

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
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

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "${aws_iam_role.iam_for_lambdas.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

resource "aws_lambda_function" "test_lambda" {
  function_name    = "lambda_function_batch"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  filename         = "${data.archive_file.zip.output_path}"
  source_code_hash = "${data.archive_file.zip.output_base64sha256}"
  handler          = "batch.lambda_handler"
  runtime          = "python3.7"

  environment {
    variables = {
      REGION = "eu-central-1"
    }
  }
}

#to add this variable later
resource "aws_cloudwatch_log_group" "log_group_batch" {
  name              = "/aws/lambda/{var.lambda.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_event_target" "cron" {
  rule      = "${aws_cloudwatch_event_rule.cron.name}"
  target_id = "test_lambda"
  arn       = "${aws_lambda_function.test_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_func_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.test_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.cron.arn}"
}
