import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import VideoList from "./VideoList";

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
    ScanIndexForward: false, // This will sort in descending order
    Limit: 5,
    ExclusiveStartKey: lastEvaluatedKey,
  });

  const response = await docClient.send(command);
  return response;
}

export default async function Page({
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
    <div>
      <h1>Manage Videos</h1>
      <VideoList videos={videos} />
      {nextPageParams && (
        <a href={`/manage${nextPageParams}`}>Next Page</a>
      )}
    </div>
  );
}
