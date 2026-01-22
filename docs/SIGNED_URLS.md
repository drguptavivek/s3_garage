# Secured Access with Presigned URLs

This guide explains how to secure your S3 resources by allowing access **only** via cryptographically signed URLs.

## Security Model

1. **Private by Default**: All buckets in Garage are private. Anonymous requests are denied (`403 Forbidden`).
2. **No Public Access**: Do not grant public read permissions to buckets.
3. **Signed Access**: Authorized users/apps generate a URL with a signature query parameter. This URL is valid for a limited time.

## Configuration

Ensure your `garage.toml` does **not** have `[s3_web]` enabled (we have disabled it in this setup).

## How to Generate Presigned URLs

You should generate these URLs on your backend server using your S3 credentials (`Access Key` and `Secret Key`). The client (browser/mobile app) then uses this URL to download the file directly from the S3 Garage.

### Using Python (Boto3)

```python
import boto3
from botocore.client import Config

# Configure S3 client
s3 = boto3.client('s3',
    endpoint_url='https://s3.example.com',
    aws_access_key_id='GKxxxxxxxx',
    aws_secret_access_key='xxxxxxxx',
    config=Config(signature_version='s3v4'),
    region_name='garage'
)

# Generate URL
url = s3.generate_presigned_url(
    ClientMethod='get_object',
    Params={
        'Bucket': 'my-private-bucket',
        'Key': 'secret-file.pdf'
    },
    ExpiresIn=3600  # URL valid for 1 hour (seconds)
)

print("Share this URL with the user:")
print(url)
```

### Using Node.js (AWS SDK v3)

```javascript
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const s3 = new S3Client({
  endpoint: "https://s3.example.com",
  region: "garage",
  credentials: {
    accessKeyId: "GKxxxxxxxx",
    secretAccessKey: "xxxxxxxx"
  }
});

const command = new GetObjectCommand({
  Bucket: "my-private-bucket",
  Key: "secret-file.pdf"
});

// Generate URL valid for 15 minutes (900 seconds)
const url = await getSignedUrl(s3, command, { expiresIn: 900 });

console.log("Signed URL:", url);
```

### Using AWS CLI (For Testing)

You can quickly generate a URL to test connectivity:

```bash
# Configure profile if not already set
aws configure set aws_access_key_id GKxxxxxxxx
aws configure set aws_secret_access_key xxxxxxxx
aws configure set region garage

# Generate URL
aws s3 presign s3://my-private-bucket/test.txt --expires-in 300 --endpoint-url https://s3.example.com
```

## Workflow

1. **Upload**: Your backend uploads the file (or generates a presigned PUT URL for client-side upload).
2. **Request**: Authenticated user requests access to a file from your backend API.
3. **Sign**: Your backend validates the user's permission (e.g., via session/JWT), generates a presigned S3 URL valid for 5 minutes.
4. **Redirect/Return**: Your backend returns the URL to the client.
5. **Download**: Client downloads the file from `https://s3.example.com/...` using the signed URL.

## Advantages

*   **Scalability**: File traffic goes directly to S3/Garage, not through your backend API.
*   **Security**: Links expire automatically. You control who gets a link.
*   **Rate Limiting**: Our OpenResty layer protects the S3 endpoint from abuse, even for signed URLs.
