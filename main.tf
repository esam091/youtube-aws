# Configure the AWS provider
provider "aws" {
  region  = var.aws_region
}

# S3 bucket for raw videos
resource "aws_s3_bucket" "raw_videos" {
  bucket = "ytaws-raw-videos-${data.aws_caller_identity.current.account_id}-${var.environment}"
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
  bucket = "ytaws-processed-videos-${data.aws_caller_identity.current.account_id}-${var.environment}"
}

# Add this new block to allow public access to the processed videos bucket
resource "aws_s3_bucket_public_access_block" "processed_videos_public_access" {
  bucket = aws_s3_bucket.processed_videos.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Add this new block to set the bucket policy for public read access
resource "aws_s3_bucket_policy" "processed_videos_policy" {
  bucket = aws_s3_bucket.processed_videos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.processed_videos.arn}/*"
      }
    ]
  })

  # Ensure the public access block is applied before the bucket policy
  depends_on = [aws_s3_bucket_public_access_block.processed_videos_public_access]
}

# New CORS configuration for processed videos bucket
resource "aws_s3_bucket_cors_configuration" "processed_videos_cors" {
  bucket = aws_s3_bucket.processed_videos.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
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

# New null_resource to download the zip file
resource "null_resource" "download_layer" {
  triggers = {
    file_hash = fileexists("ffprobe-layer.zip") ? filebase64sha256("ffprobe-layer.zip") : timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -f ffprobe-layer.zip ] || [ ! -s ffprobe-layer.zip ]; then
        echo "Downloading ffprobe-layer.zip..."
        curl -L -o ffprobe-layer.zip https://github.com/esam091/ffprobe-lambda-layer/releases/download/0.1/ffprobe-layer.zip
        if [ $? -ne 0 ] || [ ! -s ffprobe-layer.zip ]; then
          echo "Failed to download or empty file"
          exit 1
        fi
      else
        echo "ffprobe-layer.zip already exists and is not empty"
      fi
    EOT
  }
}

# New Lambda layer resource
resource "aws_lambda_layer_version" "ffprobe_layer" {
  filename   = "ffprobe-layer.zip"
  layer_name = "ytaws-ffprobe-layer"

  compatible_runtimes = ["python3.12"]

  source_code_hash = fileexists("ffprobe-layer.zip") ? filebase64sha256("ffprobe-layer.zip") : null

  depends_on = [null_resource.download_layer]
}

# Lambda function to process raw videos
resource "aws_lambda_function" "process_raw_video" {
  filename         = "process_raw_video.zip"
  function_name    = "ytaws-process-raw-video-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "process_raw_video.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  layers = [aws_lambda_layer_version.ffprobe_layer.arn]

  timeout     = 10
  memory_size = 512

  environment {
    variables = {
      S3_OUTPUT_URL     = "s3://${aws_s3_bucket.processed_videos.id}"
      SQS_QUEUE_URL     = aws_sqs_queue.raw_video_queue.url
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
  source_file = "process_raw_video.py"
  output_path = "process_raw_video.zip"
}

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "ytaws-user-pool-${var.environment}"

  auto_verified_attributes = ["email"]
  
  # Allow sign-in with email and preferred_username
  alias_attributes         = ["email", "preferred_username"]
  
  username_configuration {
    case_sensitive = false
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "preferred_username"
    attribute_data_type = "String"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

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
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "client" {
  name         = "next-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Enable all sign-in options
  supported_identity_providers = ["COGNITO"]
  prevent_user_existence_errors = "ENABLED"
}

# Elastic Beanstalk application
resource "aws_elastic_beanstalk_application" "ytaws_app" {
  name        = "ytaws-app-${var.environment}"
  description = "YT AWS Application - ${title(var.environment)}"
}

# S3 bucket for Elastic Beanstalk versions
resource "aws_s3_bucket" "eb_versions" {
  bucket = "ytaws-eb-${var.aws_region}-${data.aws_caller_identity.current.account_id}"
}

# Generate the .env file
resource "local_file" "dotenv" {
  filename = "${path.module}/webapp/.env"
  content  = <<-EOT
    NEXT_PUBLIC_AWS_USER_POOL_ID=${aws_cognito_user_pool.main.id}
    NEXT_PUBLIC_AWS_USER_POOL_CLIENT_ID=${aws_cognito_user_pool_client.client.id}
    S3_BUCKET_NAME=${aws_s3_bucket.raw_videos.id}
    VIDEOS_TABLE=${aws_dynamodb_table.videos.name}
    PROCESSED_BUCKET_DOMAIN=${aws_s3_bucket.processed_videos.bucket_regional_domain_name}
    S3_PROCESSED_BUCKET_NAME=${aws_s3_bucket.processed_videos.id}
  EOT
}

# Calculate hash of webapp directory contents, excluding node_modules and .next
data "external" "webapp_hash" {
  program = ["bash", "-c", "find webapp -type f -not -path '*/node_modules/*' -not -path '*/.next/*' -print0 | sort -z | xargs -0 sha1sum | sha1sum | cut -d' ' -f1 | jq -R '{hash: .}'"]
}

# Run the build script only when webapp contents change
resource "null_resource" "build_webapp" {
  triggers = {
    webapp_hash = data.external.webapp_hash.result.hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      cd webapp
      npm install
      npm run zip
      cd ..
    EOT
  }

  depends_on = [local_file.dotenv]
}

# Upload webapp.zip to S3
resource "aws_s3_object" "webapp_zip" {
  bucket = aws_s3_bucket.eb_versions.id
  key    = "ytaws-app-${var.environment}/webapp-${data.external.webapp_hash.result.hash}.zip"
  source = "webapp.zip"
  etag   = data.external.webapp_hash.result.hash

  depends_on = [null_resource.build_webapp]
}

# Elastic Beanstalk application version
resource "aws_elastic_beanstalk_application_version" "default" {
  name        = "ytaws-app-version-${data.external.webapp_hash.result.hash}"
  application = aws_elastic_beanstalk_application.ytaws_app.name
  description = "YT AWS Application Version - ${title(var.environment)}"
  bucket      = aws_s3_bucket.eb_versions.id
  key         = aws_s3_object.webapp_zip.id
}

# Elastic Beanstalk environment
resource "aws_elastic_beanstalk_environment" "ytaws_app_env" {
  name                = "ytaws-app-${var.environment}"
  application         = aws_elastic_beanstalk_application.ytaws_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.2.1 running Node.js 20"
  version_label       = aws_elastic_beanstalk_application_version.default.name

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

  # Add this new setting for PROCESSED_BUCKET_DOMAIN
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PROCESSED_BUCKET_DOMAIN"
    value     = aws_s3_bucket.processed_videos.bucket_regional_domain_name
  }

  # Add this new setting for S3_PROCESSED_BUCKET_NAME
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "S3_PROCESSED_BUCKET_NAME"
    value     = aws_s3_bucket.processed_videos.id
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
          "s3:PutObject",
          "s3:HeadObject",
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.raw_videos.arn}/*"
        ]
      },
      {
        Action = [
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.processed_videos.arn}",
          "${aws_s3_bucket.processed_videos.arn}/*"
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
  name         = "ytaws-videos-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name               = "UserIdIndex"
    hash_key           = "userId"
    range_key          = "id"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "status"
    range_key          = "id"
    projection_type    = "ALL"
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
        Resource = [
          aws_dynamodb_table.videos.arn,
          "${aws_dynamodb_table.videos.arn}/index/*"
        ]
      }
    ]
  })
}

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

# New SQS queue for MediaConvert job status changes
resource "aws_sqs_queue" "mediaconvert_job_queue" {
  name = "ytaws-mediaconvert-job-${var.environment}"

  # Configure the DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.mediaconvert_job_dlq.arn
    maxReceiveCount     = 3
  })
}

# Dead Letter Queue (DLQ) for failed MediaConvert job events
resource "aws_sqs_queue" "mediaconvert_job_dlq" {
  name = "ytaws-mediaconvert-job-dlq-${var.environment}"
}

# Lambda function to process MediaConvert job status changes
resource "aws_lambda_function" "process_mediaconvert_job" {
  filename         = "lambda_mediaconvert_job.zip"
  function_name    = "ytaws-process-mediaconvert-job-${var.environment}"
  role             = aws_iam_role.lambda_mediaconvert_role.arn
  handler          = "lambda_mediaconvert_job.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_mediaconvert_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.videos.name
      SQS_QUEUE_URL  = aws_sqs_queue.mediaconvert_job_queue.url
      RAW_VIDEOS_BUCKET = aws_s3_bucket.raw_videos.id  
    }
  }
}

# IAM role for the MediaConvert job Lambda function
resource "aws_iam_role" "lambda_mediaconvert_role" {
  name = "process_mediaconvert_job_lambda_role_${var.environment}"

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

# IAM policy for Lambda to access SQS, CloudWatch Logs, DynamoDB, and S3
resource "aws_iam_role_policy" "lambda_mediaconvert_policy" {
  name = "process_mediaconvert_job_lambda_policy_${var.environment}"
  role = aws_iam_role.lambda_mediaconvert_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.mediaconvert_job_queue.arn
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
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.videos.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.raw_videos.arn}/*"
      }
    ]
  })
}

# Lambda event source mapping (SQS to Lambda trigger)
resource "aws_lambda_event_source_mapping" "sqs_mediaconvert_lambda_trigger" {
  event_source_arn = aws_sqs_queue.mediaconvert_job_queue.arn
  function_name    = aws_lambda_function.process_mediaconvert_job.arn
  batch_size       = 1  # Process one message at a time
}

# Lambda function code from zip file
data "archive_file" "lambda_mediaconvert_zip" {
  type        = "zip"
  source_file = "lambda_mediaconvert_job.py"
  output_path = "lambda_mediaconvert_job.zip"
}

# CloudWatch Event Rule to capture MediaConvert job status changes
resource "aws_cloudwatch_event_rule" "mediaconvert_job_state_change" {
  name        = "capture-mediaconvert-job-state-change-${var.environment}"
  description = "Capture MediaConvert job state changes for COMPLETE and ERROR statuses, and specific bucket"

  event_pattern = jsonencode({
    source      = ["aws.mediaconvert"]
    detail-type = ["MediaConvert Job State Change"]
    detail = {
      status = ["COMPLETE", "ERROR"]
      userMetadata = {
        bucket = [aws_s3_bucket.raw_videos.id]
      }
    }
  })
}

# CloudWatch Event Target to send events to SQS
resource "aws_cloudwatch_event_target" "send_mediaconvert_job_to_sqs" {
  rule      = aws_cloudwatch_event_rule.mediaconvert_job_state_change.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.mediaconvert_job_queue.arn
}

# SQS queue policy to allow CloudWatch Events to send messages
resource "aws_sqs_queue_policy" "mediaconvert_job_queue_policy" {
  queue_url = aws_sqs_queue.mediaconvert_job_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.mediaconvert_job_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.mediaconvert_job_state_change.arn
          }
        }
      }
    ]
  })
}

# Replace the policy attachment with an inline policy
resource "aws_iam_role_policy" "cognito_list_users" {
  name = "cognito-list-users-policy-${var.environment}"
  role = aws_iam_role.eb_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cognito-idp:ListUsers"
        ]
        Effect   = "Allow"
        Resource = aws_cognito_user_pool.main.arn
      },
    ]
  })
}