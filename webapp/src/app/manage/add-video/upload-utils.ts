"use server"

import { S3Client } from "@aws-sdk/client-s3";
import { createPresignedPost } from "@aws-sdk/s3-presigned-post";
import { ulid } from 'ulid';

const MAX_FILE_SIZE = 100 * 1024 * 1024; 
const EXPIRATION_TIME = 60 * 3; 

export async function createSignedUrl() {
  const s3Client = new S3Client({
    region: process.env.AWS_REGION,
  });

  const id = ulid();

  try {
    const { url, fields } = await createPresignedPost(s3Client, {
      Bucket: process.env.S3_BUCKET_NAME!,
      Key: id,
      Conditions: [
        ["content-length-range", 0, MAX_FILE_SIZE],
      ],
      Expires: EXPIRATION_TIME,
    });

    return { url, fields, id };
  } catch (error) {
    console.error("Error creating signed URL:", error);
    throw new Error("Failed to create signed URL");
  }
}