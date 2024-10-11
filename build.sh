#!/bin/bash

# Set the names of the Lambda function files
LAMBDA_FUNCTION_FILE="lambda_function.py"
LAMBDA_MEDIACONVERT_FILE="lambda_mediaconvert_job.py"

# Set the names of the zip files
LAMBDA_FUNCTION_ZIP="lambda_function.zip"
LAMBDA_MEDIACONVERT_ZIP="lambda_mediaconvert_job.zip"

# Function to check if a file exists and create a zip file
create_zip() {
    local file=$1
    local zip_file=$2

    if [ ! -f "$file" ]; then
        echo "Error: $file not found!"
        exit 1
    fi

    echo "Creating $zip_file..."
    zip -q "$zip_file" "$file"

    if [ $? -eq 0 ]; then
        echo "Successfully created $zip_file"
    else
        echo "Error: Failed to create $zip_file"
        exit 1
    fi
}

# Create zip files for both Lambda functions
create_zip "$LAMBDA_FUNCTION_FILE" "$LAMBDA_FUNCTION_ZIP"
create_zip "$LAMBDA_MEDIACONVERT_FILE" "$LAMBDA_MEDIACONVERT_ZIP"

# Run Terraform
echo "Running Terraform..."
terraform init
terraform apply -var="aws_profile=toptal" -var="aws_region=ap-southeast-1"

# Check if Terraform apply was successful
if [ $? -eq 0 ]; then
    echo "Terraform apply completed successfully"
else
    echo "Error: Terraform apply failed"
    exit 1
fi

echo "Build process completed"