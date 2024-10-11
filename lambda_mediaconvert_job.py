import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
sqs = boto3.client('sqs')

def handler(event, context):
    for record in event['Records']:
        message = json.loads(record['body'])
        detail = message['detail']

        # Print the job detail
        print(f"Job detail: {json.dumps(detail, indent=2)}")

        # Remove the processed message from the queue
        sqs.delete_message(
            QueueUrl=os.environ['SQS_QUEUE_URL'],
            ReceiptHandle=record['receiptHandle']
        )

    # for record in event['Records']:
    #     message = json.loads(record['body'])
    #     detail = message['detail']

    #     job_id = detail['jobId']
    #     status = detail['status']

    #     try:
    #         response = table.update_item(
    #             Key={'id': job_id},
    #             UpdateExpression='SET #status = :status',
    #             ExpressionAttributeNames={'#status': 'status'},
    #             ExpressionAttributeValues={':status': status},
    #             ReturnValues='UPDATED_NEW'
    #         )
    #         print(f"Updated job {job_id} status to {status}")
    #     except ClientError as e:
    #         print(f"Error updating DynamoDB: {e.response['Error']['Message']}")

    return {
        'statusCode': 200,
        'body': json.dumps('MediaConvert job details processed and removed from queue')
    }