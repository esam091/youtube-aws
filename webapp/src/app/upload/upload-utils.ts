"use server"

import { S3Client } from "@aws-sdk/client-s3";
import { createPresignedPost } from "@aws-sdk/s3-presigned-post";

const MAX_FILE_SIZE = 100 * 1024 * 1024; // 100MB in bytes
const EXPIRATION_TIME = 60 * 3; // 3 minutes in seconds

export async function createSignedUrl(fileName: string, fileType: string) {
  const s3Client = new S3Client({
    region: process.env.AWS_REGION,
  });

  try {
    const { url, fields } = await createPresignedPost(s3Client, {
      Bucket: process.env.S3_BUCKET_NAME!,
      Key: fileName,
      Conditions: [
        ["content-length-range", 0, MAX_FILE_SIZE],
        // ["starts-with", "$Content-Type", fileType],
      ],
      Expires: EXPIRATION_TIME, // URL expires in 3 minutes
    });

    return { url, fields };
  } catch (error) {
    console.error("Error creating signed URL:", error);
    throw new Error("Failed to create signed URL");
  }
}