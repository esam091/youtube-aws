#!/bin/bash

# Set the name of the Lambda function file
LAMBDA_FILE="process_video.py"

# Set the name of the zip file
ZIP_FILE="lambda_function.zip"

# Check if the Lambda function file exists
if [ ! -f "$LAMBDA_FILE" ]; then
    echo "Error: $LAMBDA_FILE not found!"
    exit 1
fi

# Create a zip file containing the Lambda function
echo "Creating $ZIP_FILE..."
zip -q "$ZIP_FILE" "$LAMBDA_FILE"

if [ $? -eq 0 ]; then
    echo "Successfully created $ZIP_FILE"
else
    echo "Error: Failed to create $ZIP_FILE"
    exit 1
fi

# Run Terraform
echo "Running Terraform..."
terraform init
terraform apply

# Check if Terraform apply was successful
if [ $? -eq 0 ]; then
    echo "Terraform apply completed successfully"
else
    echo "Error: Terraform apply failed"
    exit 1
fi

echo "Build process completed"