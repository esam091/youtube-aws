import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { currentActiveUser } from "@/server/utils";
import { z } from "zod";
import { VideoTable } from "@/app/manage/videos/VideoTable";

const dynamoDb = DynamoDBDocumentClient.from(new DynamoDBClient({}));

// Define the Zod schema for a video
const VideoSchema = z.object({
  id: z.string(),
  userId: z.string(),
  title: z.string(),
  description: z.string(),
  status: z.union([z.literal('processing'), z.literal('done'), z.literal('failed')]),
  createdAt: z.string().datetime().transform(str => new Date(str)),
});

// Define the array schema
const VideoArraySchema = z.array(VideoSchema);

// Define the type based on the schema
type Video = z.infer<typeof VideoSchema>;

async function loadUserVideos(userId: string): Promise<Video[]> {
  const command = new QueryCommand({
    TableName: process.env.VIDEOS_TABLE,
    IndexName: "UserIdIndex",
    KeyConditionExpression: "userId = :userId",
    ExpressionAttributeValues: {
      ":userId": userId,
    },
    ScanIndexForward: false, // This will sort in descending order
  });

  try {
    const response = await dynamoDb.send(command);
    const validatedVideos = VideoArraySchema.parse(response.Items || []);
    return validatedVideos;
  } catch (error) {
    console.error("Error fetching or validating user videos:", error);
    return [];
  }
}

export default async function Page() {
  const user = await currentActiveUser();
  
  if (!user) {
    return <div>Please log in to view your videos.</div>;
  }

  const videos = await loadUserVideos(user.userId);

  return (
    <div className="container mx-auto py-10">
      <h1 className="text-2xl font-bold mb-5">Manage Videos</h1>
      {videos.length === 0 ? (
        <p>You haven&apos;t uploaded any videos yet.</p>
      ) : (
        <VideoTable videos={videos} />
      )}
    </div>
  );
}
