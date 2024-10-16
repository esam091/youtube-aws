import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";
import { CognitoIdentityProviderClient, ListUsersCommand } from "@aws-sdk/client-cognito-identity-provider";
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
  userId: z.string(),
});

type VideoData = z.infer<typeof videoSchema> & { username: string };

const dynamoClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoClient);
const cognitoClient = new CognitoIdentityProviderClient({});

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
    const videoData = videoSchema.parse(response.Item);

    // Fetch user data from Cognito using the user ID
    const cognitoCommand = new ListUsersCommand({
      UserPoolId: process.env.NEXT_PUBLIC_AWS_USER_POOL_ID,
      Filter: `sub = "${videoData.userId}"`,
      Limit: 1,
    });

    const cognitoResponse = await cognitoClient.send(cognitoCommand);
    let username = 'Unknown User';
    
    if (cognitoResponse.Users?.[0]) {
      const user = cognitoResponse.Users[0];
      username = user.Username || 'Unknown User';
    }

    return { ...videoData, username };
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
