data "aws_iam_account_alias" "current" {}

resource "aws_schemas_discoverer" "default_bus_discover" {
  source_arn  = "arn:aws:events:us-east-1:${data.aws_caller_identity.current.account_id}:event-bus/default"
  description = "Auto discover event schemas"
}

resource "aws_cloudwatch_event_rule" "capture_admin_access" {
  name        = "capture-admin-access-policy-assignment"
  description = "Capture events assigning AdministratorAccess to a user"

  event_pattern = <<EOF
{
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["iam.amazonaws.com"],
    "eventName": ["AttachUserPolicy"],
    "requestParameters": {
      "policyArn": ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "invoke_remove_admin_access" {
  target_id = "AutomateAdministratorAccessPolicyRemoval"
  rule      = aws_cloudwatch_event_rule.capture_admin_access.name
  arn       = aws_lambda_function.remove_admin_access.arn
}

resource "aws_cloudwatch_log_group" "remove_admin_access" {
  name              = "/aws/lambda/remove_admin_access"
  retention_in_days = 7
}

resource "aws_iam_policy" "remove_admin_access" {
  name = "LambdaRemoveAdministratorAccessPolicy"
  path = "/"
  description = "Remove AdministratorAccess policy and write to CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
        {
            Sid = "WriteToCloudWatch"
            Effect = "Allow"
            Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
            Resource = "*"
        },
        {
            Sid = "ManageIAM",
            Effect = "Allow",
            Action = [
                "iam:ListAttachedUserPolicies",
                "iam:DetachUserPolicy",
                "iam:ListUserPolicies",
                "iam:DeleteUserPolicy",
                "iam:DeleteLoginProfile",
                "iam:ListAccessKeys" ,
                "iam:DeleteAccessKey"   
            ]
            Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*"
        }
    ]
  })
}

resource "aws_iam_role" "remove_admin_access_role" {
  name = "LambdaRemoveAdministratorAccessRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "remove_admin_access_attachment" {
  role       = aws_iam_role.remove_admin_access_role.name
  policy_arn = aws_iam_policy.remove_admin_access.arn
}

resource "aws_lambda_permission" "eventbridge_to_remove_admin_access_function" {
    statement_id = "AllowExecutionFromEventBridge"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.remove_admin_access.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.capture_admin_access.arn
}