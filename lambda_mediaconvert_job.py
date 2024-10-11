import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
sqs = boto3.client('sqs')
s3 = boto3.client('s3')

def handler(event, context):
    for record in event['Records']:
        message = json.loads(record['body'])
        detail = message['detail']

        object_key = detail['userMetadata']['id']
        bucket = detail['userMetadata']['bucket']
        
        try:
            # video has been processed, delete it from raw video bucket
            s3.delete_object(Bucket=bucket, Key=object_key)
            print(f"Deleted object {object_key} from bucket {bucket}")
        except ClientError as e:
            print(f"Error deleting object from S3: {e.response['Error']['Message']}")

        # update the processing status in DynamoDB
        if detail['status'] == 'COMPLETE':
            status = 'done'
        elif detail['status'] == 'ERROR':
            status = 'failed'
        else:
            print(f"Unknown status: {detail['status']}")
            return {
                'statusCode': 500,
                'body': json.dumps('Unknown MediaConvert job status')
            }
        
        try:
            response = table.update_item(
                Key={'id': object_key},
                UpdateExpression='SET #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={':status': status},
                ReturnValues='UPDATED_NEW'
            )
            print(f"Updated item {object_key} status to {status}")
        except ClientError as e:
            print(f"Error updating DynamoDB: {e.response['Error']['Message']}")

        # Remove the processed message from the queue
        sqs.delete_message(
            QueueUrl=os.environ['SQS_QUEUE_URL'],
            ReceiptHandle=record['receiptHandle']
        )

    return {
        'statusCode': 200,
        'body': json.dumps('MediaConvert job details processed and removed from queue')
    }