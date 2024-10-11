"use server"

import { S3Client, HeadObjectCommand } from "@aws-sdk/client-s3";
import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { currentActiveUser } from "@/server/utils";

const s3Client = new S3Client({ region: process.env.AWS_REGION });
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION });

export async function submitUploadForm({ title, description, id }: { title: string, description: string, id: string }) {
  // We only insert into the database if the video file exists in S3
  try {
    await s3Client.send(new HeadObjectCommand({
      Bucket: process.env.S3_BUCKET_NAME,
      Key: id
    }));
  } catch (error) {
    throw new Error("Video file not found in S3 bucket");
  }

  const user = await currentActiveUser();
  if (!user) {
    throw new Error("User not authenticated");
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