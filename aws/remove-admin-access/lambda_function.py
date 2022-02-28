import json
import boto3

def lambda_handler(event, context):
    username = event["detail"]["requestParameters"]["userName"]
    client = boto3.client('iam')

    # Remove all policies
    response = client.list_attached_user_policies(
        UserName=username
    )
    for arn in response["AttachedPolicies"]:
        client.detach_user_policy(
            UserName=username,
            PolicyArn=arn["PolicyArn"]
        )

    response = client.list_user_policies(
        UserName=username
    )
    for policyName in response["PolicyNames"]:
        client.delete_user_policy(
            UserName=username,
            PolicyName=policyName
        )

    # Remove login profile
    client.delete_login_profile(
        UserName=username
    )

    # Remove access keys
    response = client.list_access_keys(
        UserName=username
    )
    for key in response["AccessKeyMetadata"]:
        client.delete_access_key(
            UserName=username,
            AccessKeyId=key["AccessKeyId"]
        )

    # Write log to CloudWatch
    print("AdministratorAccess policy removed and credentials invalidated for " + username)