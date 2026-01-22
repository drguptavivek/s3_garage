# Garage S3 Examples

This directory contains code examples for interacting with Garage S3.

## Generate Signed URL

### Node.js

1. Install dependencies:
   ```bash
   npm install
   ```

2. Run:
   ```bash
   export AWS_ACCESS_KEY_ID=GKxxxxxxxx
   export AWS_SECRET_ACCESS_KEY=xxxxxxxx
   
   node generate-signed-url.js my-bucket my-file.txt
   ```

### Python

1. Install dependencies:
   ```bash
   pip install boto3
   ```

2. Run:
   ```bash
   export AWS_ACCESS_KEY_ID=GKxxxxxxxx
   export AWS_SECRET_ACCESS_KEY=xxxxxxxx
   
   python generate-signed-url.py my-bucket my-file.txt
   ```
