# Configure the AWS provider
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# S3 bucket for raw videos
resource "aws_s3_bucket" "raw_videos" {
  bucket = "ytaws-raw-videos"
}

# S3 bucket for processed videos
resource "aws_s3_bucket" "processed_videos" {
  bucket = "ytaws-processed-videos"
}

# SQS queue for raw video events
resource "aws_sqs_queue" "raw_video_queue" {
  name = "raw-video-queue"

  # Configure the DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.raw_video_dlq.arn
    maxReceiveCount     = 3
  })

  # Add policy to allow S3 to send messages to this queue
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "sqs:SendMessage"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:raw-video-queue"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.raw_videos.arn
          }
        }
      }
    ]
  })
}

# Dead Letter Queue (DLQ) for failed events
resource "aws_sqs_queue" "raw_video_dlq" {
  name = "raw-video-queue-dlq"
}

# Lambda function to process raw videos
resource "aws_lambda_function" "process_raw_video" {
  filename         = "lambda_function.zip"
  function_name    = "process-raw-video"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      S3_OUTPUT_URL    = aws_s3_bucket.processed_videos.bucket_regional_domain_name
      SQS_QUEUE_URL    = aws_sqs_queue.raw_video_queue.url
      MEDIACONVERT_ROLE = aws_iam_role.mediaconvert_role.arn
    }
  }
}

# IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "process_raw_video_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM role for MediaConvert
resource "aws_iam_role" "mediaconvert_role" {
  name = "mediaconvert_processing_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda to access S3, CloudWatch Logs, and SQS
resource "aws_iam_role_policy" "lambda_policy" {
  name = "process_raw_video_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.raw_videos.arn}",
          "${aws_s3_bucket.raw_videos.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.processed_videos.arn}",
          "${aws_s3_bucket.processed_videos.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "mediaconvert:CreateJob",
          "mediaconvert:GetJob",
          "mediaconvert:ListJobs",
          "mediaconvert:CancelJob",
          "mediaconvert:CreateJobTemplate",
          "mediaconvert:GetJobTemplate",
          "mediaconvert:ListJobTemplates",
          "mediaconvert:DeleteJobTemplate",
          "mediaconvert:UpdateJobTemplate",
          "mediaconvert:ListPresets",
          "mediaconvert:GetPreset",
          "mediaconvert:DescribeEndpoints"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.mediaconvert_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.raw_video_queue.arn
      }
    ]
  })
}

# IAM policy for MediaConvert to access S3
resource "aws_iam_role_policy" "mediaconvert_policy" {
  name = "mediaconvert_s3_access_policy"
  role = aws_iam_role.mediaconvert_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.raw_videos.arn}",
          "${aws_s3_bucket.raw_videos.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.processed_videos.arn}",
          "${aws_s3_bucket.processed_videos.arn}/*"
        ]
      }
    ]
  })
}

# S3 bucket notification to SQS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.raw_videos.id

  queue {
    queue_arn = aws_sqs_queue.raw_video_queue.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

# Lambda event source mapping (SQS to Lambda trigger)
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.raw_video_queue.arn
  function_name    = aws_lambda_function.process_raw_video.arn
  batch_size       = 1  # Process one message at a time
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "default"  # You can set a default profile here
}

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Lambda function code from zip file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}