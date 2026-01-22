// Example: Generate Presigned URL for Garage S3
// Usage: node generate-signed-url.js <bucket> <key>

import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

// Check args
const bucket = process.argv[2];
const key = process.argv[3];

if (!bucket || !key) {
  console.error("Usage: node generate-signed-url.js <bucket> <key>");
  process.exit(1);
}

// Configuration (Load from env or default)
const endpoint = process.env.S3_ENDPOINT || "http://localhost:3900";
const region = process.env.S3_REGION || "garage";
const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;

if (!accessKeyId || !secretAccessKey) {
  console.error("Error: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables must be set.");
  process.exit(1);
}

const s3 = new S3Client({
  endpoint,
  region,
  credentials: {
    accessKeyId,
    secretAccessKey
  },
  forcePathStyle: true // Garage/MinIO often require this for http://localhost
});

async function generateUrl() {
  try {
    const command = new GetObjectCommand({
      Bucket: bucket,
      Key: key
    });

    // URL valid for 1 hour (3600 seconds)
    const url = await getSignedUrl(s3, command, { expiresIn: 3600 });

    console.log("✅ Signed URL generated successfully (valid for 1 hour):");
    console.log("-------------------------------------------------------");
    console.log(url);
    console.log("-------------------------------------------------------");
  } catch (err) {
    console.error("Error generating signed URL:", err);
  }
}

generateUrl();
