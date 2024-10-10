import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb'

const client = new DynamoDBClient({
  region: process.env.AWS_REGION!,
})

async function myAction() {
  "use server"
  
  await client.send(new PutItemCommand({
    TableName: process.env.VIDEOS_TABLE!,
    Item: {
      id: { S: new Date().toISOString() },
      title: { S: 'Sample Video '+ Math.random() },
      description: { S: 'This is a sample video entry' },
      createdAt: { S: new Date().toISOString() },
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