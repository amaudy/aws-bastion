#!/usr/bin/env python3

import boto3
import sys
import argparse
from botocore.exceptions import ClientError

def create_s3_bucket(bucket_name, region):
    """Create an S3 bucket for Terraform state"""
    s3_client = boto3.client('s3', region_name=region)
    
    try:
        # Check if bucket exists
        try:
            s3_client.head_bucket(Bucket=bucket_name)
            print(f"Bucket {bucket_name} already exists")
            return True
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                # Create bucket with versioning
                if region == 'us-east-1':
                    s3_client.create_bucket(Bucket=bucket_name)
                else:
                    s3_client.create_bucket(
                        Bucket=bucket_name,
                        CreateBucketConfiguration={'LocationConstraint': region}
                    )
                print(f"Created S3 bucket: {bucket_name}")

                # Enable versioning
                s3_client.put_bucket_versioning(
                    Bucket=bucket_name,
                    VersioningConfiguration={'Status': 'Enabled'}
                )
                print("Enabled bucket versioning")

                # Enable server-side encryption
                s3_client.put_bucket_encryption(
                    Bucket=bucket_name,
                    ServerSideEncryptionConfiguration={
                        'Rules': [
                            {
                                'ApplyServerSideEncryptionByDefault': {
                                    'SSEAlgorithm': 'AES256'
                                }
                            }
                        ]
                    }
                )
                print("Enabled default encryption")

                # Block public access
                s3_client.put_public_access_block(
                    Bucket=bucket_name,
                    PublicAccessBlockConfiguration={
                        'BlockPublicAcls': True,
                        'IgnorePublicAcls': True,
                        'BlockPublicPolicy': True,
                        'RestrictPublicBuckets': True
                    }
                )
                print("Blocked public access")

                return True
            else:
                raise

    except ClientError as e:
        print(f"Error creating S3 bucket: {e}")
        return False

def create_dynamodb_table(table_name, region):
    """Create a DynamoDB table for Terraform state locking"""
    dynamodb = boto3.client('dynamodb', region_name=region)
    
    try:
        # Check if table exists
        try:
            dynamodb.describe_table(TableName=table_name)
            print(f"DynamoDB table {table_name} already exists")
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                # Create the DynamoDB table
                dynamodb.create_table(
                    TableName=table_name,
                    KeySchema=[
                        {
                            'AttributeName': 'LockID',
                            'KeyType': 'HASH'
                        }
                    ],
                    AttributeDefinitions=[
                        {
                            'AttributeName': 'LockID',
                            'AttributeType': 'S'
                        }
                    ],
                    BillingMode='PAY_PER_REQUEST'
                )
                print(f"Created DynamoDB table: {table_name}")
                
                # Wait for the table to be created
                waiter = dynamodb.get_waiter('table_exists')
                waiter.wait(TableName=table_name)
                return True
            else:
                raise

    except ClientError as e:
        print(f"Error creating DynamoDB table: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Provision Terraform backend resources')
    parser.add_argument('--project', required=True, help='Project name')
    parser.add_argument('--region', default='us-west-2', help='AWS region (default: us-west-2)')
    args = parser.parse_args()

    # Resource names
    bucket_name = f"{args.project}-terraform-state"
    table_name = "terraform-state-lock"

    # Create resources
    if create_s3_bucket(bucket_name, args.region):
        if create_dynamodb_table(table_name, args.region):
            print("\nTerraform backend resources created successfully!")
            print("\nBackend configuration:")
            print(f"""
terraform {{
  backend "s3" {{
    bucket         = "{bucket_name}"
    key            = "env/terraform.tfstate"
    region         = "{args.region}"
    dynamodb_table = "{table_name}"
    encrypt        = true
  }}
}}
""")
        else:
            print("Failed to create DynamoDB table")
            sys.exit(1)
    else:
        print("Failed to create S3 bucket")
        sys.exit(1)

if __name__ == '__main__':
    main() 