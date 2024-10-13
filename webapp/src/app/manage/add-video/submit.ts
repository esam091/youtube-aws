"use server"

import { S3Client, HeadObjectCommand } from "@aws-sdk/client-s3";
import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { currentActiveUser } from "@/server/utils";

const s3Client = new S3Client({ region: process.env.AWS_REGION });
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION });

export async function submitUploadForm({ title, description, id }: { title: string, description: string, id: string }) {
  const user = await currentActiveUser();
  if (!user) {
    throw new Error("User not authenticated");
  }

  // Check if the file exists and get its metadata
  try {
    const { Metadata } = await s3Client.send(new HeadObjectCommand({
      Bucket: process.env.S3_BUCKET_NAME,
      Key: id
    }));

    const s3UserId = Metadata?.['userid'];

    if (!s3UserId) {
      throw new Error("User ID metadata not found on S3 object");
    }

    if (s3UserId !== user.userId) {
      console.log("S3 object user ID does not match current user ID. No action taken.");
      return;
    }

  } catch (error) {
    console.error("Error checking S3 object:", error);
    throw new Error("Failed to verify video file in S3 bucket");
  }

  // Insert into VIDEOS_TABLE
  const item = {
    id: { S: id },
    title: { S: title },
    description: { S: description },
    createdAt: { S: new Date().toISOString() },
    status: { S: "processing" },
    userId: { S: user.userId }
  };

  try {
    await dynamoClient.send(new PutItemCommand({
      TableName: process.env.VIDEOS_TABLE,
      Item: item
    }));
  } catch (error) {
    console.error("Error inserting into DynamoDB:", error);
    throw new Error("Failed to save video information");
  }
}
