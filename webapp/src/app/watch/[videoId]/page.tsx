import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";
import { z } from "zod";
import { notFound } from "next/navigation";
import WatchPageClient from "./WatchPageClient";

interface WatchPageProps {
  params: {
    videoId: string;
  };
}

const videoSchema = z.object({
  id: z.string(),
  title: z.string(),
  description: z.string(),
});

type VideoData = z.infer<typeof videoSchema>;

const dynamoClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoClient);

async function getVideoData(videoId: string): Promise<VideoData | null> {
  const command = new GetCommand({
    TableName: process.env.VIDEOS_TABLE,
    Key: { id: videoId },
  });

  try {
    const response = await docClient.send(command);
    if (!response.Item) {
      return null;
    }
    return videoSchema.parse(response.Item);
  } catch (error) {
    console.error("Error fetching video data:", error);
    throw error;
  }
}

export default async function WatchPage({ params }: WatchPageProps) {
  const { videoId } = params;
  const processedBucketDomain = process.env.PROCESSED_BUCKET_DOMAIN;

  if (!processedBucketDomain) {
    throw new Error("PROCESSED_BUCKET_DOMAIN is not set");
  }

  try {
    const videoData = await getVideoData(videoId);

    if (!videoData) {
      notFound();
    }

    return (
      <WatchPageClient
        videoId={videoId}
        processedBucketDomain={processedBucketDomain}
        videoData={videoData}
      />
    );
  } catch (error) {
    console.error("Error in WatchPage:", error);
    throw error; // Let Next.js handle the error
  }
}
