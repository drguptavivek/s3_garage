import boto3
import sys
import os
from botocore.client import Config

# Check args
if len(sys.argv) < 3:
    print("Usage: python generate-signed-url.py <bucket> <key>")
    sys.exit(1)

bucket = sys.argv[1]
key = sys.argv[2]

# Configuration
endpoint = os.getenv('S3_ENDPOINT', 'http://localhost:3900')
access_key = os.getenv('AWS_ACCESS_KEY_ID')
secret_key = os.getenv('AWS_SECRET_ACCESS_KEY')
region = os.getenv('S3_REGION', 'garage')

if not access_key or not secret_key:
    print("Error: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables must be set.")
    sys.exit(1)

# Configure S3 client
s3 = boto3.client('s3',
    endpoint_url=endpoint,
    aws_access_key_id=access_key,
    aws_secret_access_key=secret_key,
    config=Config(signature_version='s3v4'),
    region_name=region
)

try:
    url = s3.generate_presigned_url(
        ClientMethod='get_object',
        Params={
            'Bucket': bucket,
            'Key': key
        },
        ExpiresIn=3600
    )
    
    print("✅ Signed URL generated successfully (valid for 1 hour):")
    print("-------------------------------------------------------")
    print(url)
    print("-------------------------------------------------------")

except Exception as e:
    print(f"Error: {e}")
