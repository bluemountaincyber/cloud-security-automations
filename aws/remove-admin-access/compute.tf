data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "remove_admin_access" {
  filename      = "${path.module}/lambda_function.zip"
  function_name = "remove-admin-access"
  role          = aws_iam_role.remove_admin_access_role.arn
  handler       = "lambda_function.lambda_handler"

  runtime = "python3.9"
  depends_on = [
    data.archive_file.lambda_zip,
    aws_cloudwatch_log_group.remove_admin_access
  ]
}