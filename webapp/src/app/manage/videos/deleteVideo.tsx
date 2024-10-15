"use server"

import { currentActiveUser } from '@/server/utils';
import { DynamoDBDocumentClient, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { S3Client, DeleteObjectsCommand, ListObjectsV2Command } from "@aws-sdk/client-s3";

export default async function deleteVideo(videoId: string) {
  const user = await currentActiveUser();
  if (!user) {
    throw new Error('User not authenticated');
  }

  const dynamoClient = new DynamoDBClient({});
  const docClient = DynamoDBDocumentClient.from(dynamoClient);
  const s3Client = new S3Client({});

  const tableName = process.env.VIDEOS_TABLE;
  const bucketName = process.env.S3_PROCESSED_BUCKET_NAME;

  if (!tableName) {
    throw new Error('VIDEOS_TABLE environment variable is not set');
  }
  if (!bucketName) {
    throw new Error('S3_PROCESSED_BUCKET_NAME environment variable is not set');
  }

  try {
    const deleteParams = {
      TableName: tableName,
      Key: { id: videoId },
      ConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': user.userId
      }
    };
    await docClient.send(new DeleteCommand(deleteParams));

    // Delete from S3
    const listParams = {
      Bucket: bucketName,
      Prefix: `${videoId}/`
    };

    const listedObjects = await s3Client.send(new ListObjectsV2Command(listParams));

    if (listedObjects.Contents && listedObjects.Contents.length > 0) {
      const deleteParams = {
        Bucket: bucketName,
        Delete: { Objects: listedObjects.Contents.map(({ Key }) => ({ Key })) }
      };

      await s3Client.send(new DeleteObjectsCommand(deleteParams));
    }

  } catch (error) {
    console.error('Error deleting video:', error);
    if (error instanceof Error && error.name === 'ConditionalCheckFailedException') {
      throw new Error('Video not found or not authorized to delete this video');
    }
    throw error;
  }
}
