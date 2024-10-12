import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import VideoList from "./VideoList";
import Link from "next/link";

const dynamoDb = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoDb);

async function getVideos(lastEvaluatedKey?: { id: string; status: string }) {
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
    Limit: 10, 
    ExclusiveStartKey: lastEvaluatedKey,
  });

  const response = await docClient.send(command);
  return response;
}

export default async function Home({
  searchParams,
}: {
  searchParams: { lastId?: string; lastStatus?: string };
}) {
  const lastEvaluatedKey = searchParams.lastId && searchParams.lastStatus
    ? { id: searchParams.lastId, status: searchParams.lastStatus }
    : undefined;

  const { Items: videos = [], LastEvaluatedKey } = await getVideos(lastEvaluatedKey);

  const nextPageParams = LastEvaluatedKey
    ? `?lastId=${encodeURIComponent(LastEvaluatedKey.id)}&lastStatus=${encodeURIComponent(LastEvaluatedKey.status)}`
    : null;

  return (
    <div className="container mx-auto px-4">
      <h1 className="text-3xl font-bold my-8">Welcome to YT AWS</h1>
      <div className="mb-8">
        <Link href="/manage/add-video" className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
          Upload New Video
        </Link>
      </div>
      <h2 className="text-2xl font-semibold mb-4">Recent Videos</h2>
      <VideoList videos={videos} />
      {nextPageParams && (
        <div className="mt-4">
          <Link href={`/${nextPageParams}`} className="text-blue-500 hover:underline">
            Load More Videos
          </Link>
        </div>
      )}
    </div>
  );
}
