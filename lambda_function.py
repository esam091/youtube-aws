import json
import boto3
import os

# Initialize AWS clients
s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')
mediaconvert_client = boto3.client('mediaconvert')

# Get environment variables
S3_OUTPUT_URL = os.environ['S3_OUTPUT_URL']
MEDIACONVERT_ROLE = os.environ['MEDIACONVERT_ROLE']
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']

def get_mediaconvert_endpoint():
    response = mediaconvert_client.describe_endpoints()
    return response['Endpoints'][0]['Url']

# Get MediaConvert endpoint
MEDIACONVERT_ENDPOINT = get_mediaconvert_endpoint()

# Re-initialize MediaConvert client with the correct endpoint
mediaconvert_client = boto3.client('mediaconvert', endpoint_url=MEDIACONVERT_ENDPOINT)

def handler(event, context):
    try:
        # Process SQS messages
        for record in event['Records']:
            # Extract message body and receipt handle
            message_body = json.loads(record['body'])
            receipt_handle = record['receiptHandle']

            # Process the S3 event from the SQS message
            for s3_record in message_body['Records']:
                bucket_name = s3_record['s3']['bucket']['name']
                object_key = s3_record['s3']['object']['key']
                
                # Process S3 object with MediaConvert
                process_s3_object(bucket_name, object_key)

            # Delete the processed message from the queue
            delete_sqs_message(receipt_handle)

        return {
            'statusCode': 200,
            'body': json.dumps('Processing completed successfully')
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error occurred: {str(e)}')
        }

def process_s3_object(bucket_name, object_key):
    input_url = f's3://{bucket_name}/{object_key}'
    output_url = S3_OUTPUT_URL
    
    if not output_url.endswith('/'):
        output_url += '/'
    
    job_settings = {
        "Inputs": [{
            "FileInput": input_url,
            "AudioSelectors": {
                "Audio Selector 1": {
                    "DefaultSelection": "DEFAULT"
                }
            },
            "VideoSelector": {
                "ColorSpace": "FOLLOW"
            }
        }],
        "OutputGroups": [
            {
                "Name": "File Group",
                "OutputGroupSettings": {
                    "Type": "FILE_GROUP_SETTINGS",
                    "FileGroupSettings": {
                        "Destination": f"{output_url}thumbnail/"
                    }
                },
                "Outputs": [{
                    "VideoDescription": {
                        "CodecSettings": {
                            "Codec": "FRAME_CAPTURE",
                            "FrameCaptureSettings": {
                                "MaxCaptures": 1,
                                "Quality": 80
                            }
                        },
                        "Height": 100,
                        "ScalingBehavior": "STRETCH_TO_OUTPUT"
                    },
                    "ContainerSettings": {
                        "Container": "RAW"
                    },
                    "NameModifier": "_thumbnail"
                }]
            },
            {
                "Name": "Apple HLS",
                "OutputGroupSettings": {
                    "Type": "HLS_GROUP_SETTINGS",
                    "HlsGroupSettings": {
                        "Destination": f"{output_url}hls/",
                        "SegmentLength": 10,
                        "MinSegmentLength": 0,
                    }
                },
                "Outputs": [
                    {
                        "NameModifier": "_720p",
                        "VideoDescription": {
                            "Width": 1280,
                            "Height": 720,
                            "ScalingBehavior": "DEFAULT",
                            "CodecSettings": {
                                "Codec": "H_264",
                                "H264Settings": {
                                    "MaxBitrate": 3000000,
                                    "RateControlMode": "QVBR",
                                    "SceneChangeDetect": "TRANSITION_DETECTION"
                                }
                            }
                        },
                        "AudioDescriptions": [
                            {
                                "AudioSourceName": "Audio Selector 1",
                                "CodecSettings": {
                                    "Codec": "AAC",
                                    "AacSettings": {
                                        "Bitrate": 128000,
                                        "CodingMode": "CODING_MODE_2_0",
                                        "SampleRate": 48000
                                    }
                                }
                            }
                        ],
                        "ContainerSettings": {
                            "Container": "M3U8",
                            "M3u8Settings": {}
                        }
                    },
                    {
                        "NameModifier": "_480p",
                        "VideoDescription": {
                            "Width": 854,
                            "Height": 480,
                            "ScalingBehavior": "DEFAULT",
                            "CodecSettings": {
                                "Codec": "H_264",
                                "H264Settings": {
                                    "MaxBitrate": 1500000,
                                    "RateControlMode": "QVBR",
                                    "SceneChangeDetect": "TRANSITION_DETECTION"
                                }
                            }
                        },
                        "AudioDescriptions": [
                            {
                                "AudioSourceName": "Audio Selector 1",
                                "CodecSettings": {
                                    "Codec": "AAC",
                                    "AacSettings": {
                                        "Bitrate": 96000,
                                        "CodingMode": "CODING_MODE_2_0",
                                        "SampleRate": 48000
                                    }
                                }
                            }
                        ],
                        "ContainerSettings": {
                            "Container": "M3U8",
                            "M3u8Settings": {}
                        }
                    },
                    {
                        "NameModifier": "_360p",
                        "VideoDescription": {
                            "Width": 640,
                            "Height": 360,
                            "ScalingBehavior": "DEFAULT",
                            "CodecSettings": {
                                "Codec": "H_264",
                                "H264Settings": {
                                    "MaxBitrate": 1000000,
                                    "RateControlMode": "QVBR",
                                    "SceneChangeDetect": "TRANSITION_DETECTION"
                                }
                            }
                        },
                        "AudioDescriptions": [
                            {
                                "AudioSourceName": "Audio Selector 1",
                                "CodecSettings": {
                                    "Codec": "AAC",
                                    "AacSettings": {
                                        "Bitrate": 96000,
                                        "CodingMode": "CODING_MODE_2_0",
                                        "SampleRate": 48000
                                    }
                                }
                            }
                        ],
                        "ContainerSettings": {
                            "Container": "M3U8",
                            "M3u8Settings": {}
                        }
                    }
                ]
            }
        ]
    }

    response = mediaconvert_client.create_job(
        Role=MEDIACONVERT_ROLE,
        Settings=job_settings,
        UserMetadata={
            "id": object_key,
            "bucket": bucket_name
        }
    )
    
    print(f"MediaConvert job created: {response['Job']['Id']}")


def delete_sqs_message(receipt_handle):
    sqs_client.delete_message(
        QueueUrl=SQS_QUEUE_URL,
        ReceiptHandle=receipt_handle
    )