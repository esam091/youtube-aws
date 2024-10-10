# Add this at the beginning of the file
variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
  default     = "dev"
}

# Configure the AWS provider
provider "aws" {
  region  = var.aws_region
}

# S3 bucket for raw videos
resource "aws_s3_bucket" "raw_videos" {
  bucket = "ytaws-raw-videos-3892-${var.environment}"
}

# CORS configuration for raw videos bucket
resource "aws_s3_bucket_cors_configuration" "raw_videos_cors" {
  bucket = aws_s3_bucket.raw_videos.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST"]
    allowed_origins = concat(
      ["http://${aws_elastic_beanstalk_environment.ytaws_app_env.cname}"],
      var.environment == "dev" ? ["http://localhost:3000"] : []
    )
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 bucket for processed videos
resource "aws_s3_bucket" "processed_videos" {
  bucket = "ytaws-processed-videos-3892-${var.environment}"
}

# SQS queue for raw video events
resource "aws_sqs_queue" "raw_video_queue" {
  name = "raw-video-queue-${var.environment}"

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
        Resource = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:raw-video-queue-${var.environment}"
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
  name = "raw-video-queue-dlq-${var.environment}"
}

# Lambda function to process raw videos
resource "aws_lambda_function" "process_raw_video" {
  filename         = "lambda_function.zip"
  function_name    = "process-raw-video-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.10"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      S3_OUTPUT_URL    = "s3://${aws_s3_bucket.processed_videos.id}"
      SQS_QUEUE_URL    = aws_sqs_queue.raw_video_queue.url
      MEDIACONVERT_ROLE = aws_iam_role.mediaconvert_role.arn
    }
  }
}

# IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "process_raw_video_lambda_role_${var.environment}"

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
  name = "mediaconvert_processing_role_${var.environment}"

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
  name = "process_raw_video_lambda_policy_${var.environment}"
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
  name = "mediaconvert_s3_access_policy_${var.environment}"
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

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "ytaws-user-pool-${var.environment}"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = var.environment == "dev" ? 6 : 8
    require_lowercase = var.environment == "dev" ? false : true
    require_numbers   = var.environment == "dev" ? false : true
    require_symbols   = var.environment == "dev" ? false : true
    require_uppercase = var.environment == "dev" ? false : true
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  # Keep original attribute value active when an update is pending
  # This is the default behavior, so we don't need to specify anything for this

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "client" {
  name         = "next-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Elastic Beanstalk application
resource "aws_elastic_beanstalk_application" "ytaws_app" {
  name        = "ytaws-app-${var.environment}"
  description = "YT AWS Application - ${title(var.environment)}"
}

# Elastic Beanstalk environment
resource "aws_elastic_beanstalk_environment" "ytaws_app_env" {
  name                = "ytaws-app-${var.environment}"
  application         = aws_elastic_beanstalk_application.ytaws_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.2.1 running Node.js 20"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "1"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "S3_BUCKET_NAME"
    value     = aws_s3_bucket.raw_videos.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NEXT_PUBLIC_AWS_USER_POOL_ID"
    value     = aws_cognito_user_pool.main.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NEXT_PUBLIC_AWS_USER_POOL_CLIENT_ID"
    value     = aws_cognito_user_pool_client.client.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "AWS_REGION"
    value     = var.aws_region
  }

  # Add this new setting for VIDEOS_TABLE
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VIDEOS_TABLE"
    value     = aws_dynamodb_table.videos.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "7"
  }
}

# IAM role for Elastic Beanstalk instances
resource "aws_iam_role" "eb_instance_role" {
  name = "ytaws-eb-instance-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM instance profile for Elastic Beanstalk
resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "ytaws-eb-instance-profile-${var.environment}"
  role = aws_iam_role.eb_instance_role.name
}

# IAM policy for S3 access
resource "aws_iam_role_policy" "s3_access" {
  name = "ytaws-s3-access-${var.environment}"
  role = aws_iam_role.eb_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.raw_videos.arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for CloudWatch Logs access
resource "aws_iam_role_policy" "cloudwatch_logs_access" {
  name = "ytaws-cloudwatch-logs-access-${var.environment}"
  role = aws_iam_role.eb_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# DynamoDB table for videos
resource "aws_dynamodb_table" "videos" {
  name           = "ytaws-videos-${var.environment}"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment = var.environment
  }
}

# IAM policy for DynamoDB access
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "ytaws-dynamodb-access-${var.environment}"
  role = aws_iam_role.eb_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.videos.arn
      }
    ]
  })
}

# resource "local_file" "dotenv" {
#   filename = "${path.module}/webapp/.env"
#   content  = <<-EOT
#     NEXT_PUBLIC_AWS_REGION=${var.aws_region}
#     NEXT_PUBLIC_AWS_USER_POOL_ID=${aws_cognito_user_pool.main.id}
#     NEXT_PUBLIC_AWS_USER_POOL_CLIENT_ID=${aws_cognito_user_pool_client.client.id}
#     S3_BUCKET_NAME=${aws_s3_bucket.raw_videos.id}
#     VIDEOS_TABLE=${aws_dynamodb_table.videos.name}
#   EOT
# }

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
  }
}

# No need to configure the local provider