import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb'

const client = new DynamoDBClient({
  region: process.env.AWS_REGION!,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})

async function myAction() {
  "use server"
  
  await client.send(new PutItemCommand({
    TableName: 'ytaws-videos-test',
    Item: {
      id: { S: '1' },
      title: { S: 'Sample Video' },
      description: { S: 'This is a sample video entry' },
      createdAt: { S: new Date().toISOString() },
      uploadDate: { S: new Date().toISOString() },
    },
  }))
}

export default function Page() {
  return <div>
    <div>something</div>
    <div>
      <form action={myAction}>
        <button >
          click me
        </button>
      </form>
    </div>
  </div>
}