import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
sqs = boto3.client('sqs')
s3 = boto3.client('s3')

PROCESSED_BUCKET_DOMAIN = os.environ['PROCESSED_BUCKET_DOMAIN']
processed_bucket_url = f"https://{PROCESSED_BUCKET_DOMAIN}"

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
        
        # Extract duration from HLS_GROUP output details
        duration = None
        for output_group in detail.get('outputGroupDetails', []):
            if output_group.get('type') == 'HLS_GROUP':
                for output in output_group.get('outputDetails', []):
                    duration_ms = output.get('durationInMs')
                    if duration_ms:
                        duration = int(duration_ms / 1000)  # Convert to seconds and remove fractional part
                        break
                if duration:
                    break
        
        try:
            update_expression = 'SET #status = :status'
            expression_attribute_values = {':status': status}
            
            if duration is not None:
                update_expression += ', videoDuration = :duration'
                expression_attribute_values[':duration'] = duration

            response = table.update_item(
                Key={'id': object_key},
                UpdateExpression=update_expression,
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues=expression_attribute_values,
                ReturnValues='UPDATED_NEW'
            )
            print(f"Updated item {object_key} status to {status} and duration to {duration} seconds")
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
