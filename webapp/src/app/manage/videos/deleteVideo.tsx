"use server"

import { currentActiveUser } from '@/server/utils';
import { DynamoDBDocumentClient, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

export default async function deleteVideo(videoId: string) {
  const user = await currentActiveUser();
  if (!user) {
    throw new Error('User not authenticated');
  }

  const client = new DynamoDBClient({});
  const docClient = DynamoDBDocumentClient.from(client);

  const tableName = process.env.VIDEOS_TABLE;
  if (!tableName) {
    throw new Error('VIDEOS_TABLE environment variable is not set');
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
  } catch (error) {
    console.error('Error deleting video:', error);
    if (error instanceof Error && error.name === 'ConditionalCheckFailedException') {
      throw new Error('Video not found or not authorized to delete this video');
    }
    throw error;
  }
}
