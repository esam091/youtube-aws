import { z } from "zod";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import VideoList from "./VideoList";
import Link from "next/link";
import { videoSchema } from '@/lib/video';

const videoArraySchema = z.array(videoSchema);

const dynamoDb = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoDb);

async function getVideos() {
  const command = new QueryCommand({
    TableName: process.env.VIDEOS_TABLE,
    IndexName: "StatusIndex",
    KeyConditionExpression: "#status = :status",
    ExpressionAttributeNames: {
      "#status": "status",
    },
    ExpressionAttributeValues: {
      ":status": "done",
    },
    ScanIndexForward: false,
  });

  const response = await docClient.send(command);
  
  // Validate the response
  const validatedVideos = videoArraySchema.parse(response.Items);
  
  return validatedVideos;
}

export default async function Home() {
  const videos = await getVideos();

  return (
    <div className="container mx-auto px-4">
      <h1 className="text-3xl font-bold my-8">Welcome</h1>
      <div className="mb-8">
        <Link href="/manage/add-video" className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
          Upload New Video
        </Link>
      </div>
      <h2 className="text-2xl font-semibold mb-4">Recent Videos</h2>
      <VideoList 
        videos={videos} 
        processedBucketDomain={process.env.PROCESSED_BUCKET_DOMAIN || ''}
      />
    </div>
  );
}

export const dynamic = 'force-dynamic';