#!/bin/bash
LOG_FILE="/home/ubuntu/script.log"

# Redirect stdout and stderr to the log file
exec > >(tee -a $LOG_FILE) 2>&1

# Define the parameter names
BUCKET_NAME_PARAM="s3_bucket_name"
OBJECT_KEY_PARAM="s3_object_key"

# Define variables
ACCOUNT_ID=""
ROLE_NAME=""
DATASTORE_ID=""
REGION=""

# Retrieve the parameters from SSM Parameter Store
BUCKET_NAME=$(aws ssm get-parameter --name $BUCKET_NAME_PARAM --query "Parameter.Value" --output text)
OBJECT_KEY=$(aws ssm get-parameter --name $OBJECT_KEY_PARAM --query "Parameter.Value" --output text)

# Check if parameters are retrieved successfully
if [ -z "$BUCKET_NAME" ] || [ -z "$OBJECT_KEY" ]; then
  echo "Failed to retrieve parameters from SSM Parameter Store"
  exit 1
fi

# Define the local destination paths
INPUT_PATH="/home/ubuntu/input"
OUTPUT_PATH="/home/ubuntu/output"
mkdir -p $INPUT_PATH
mkdir -p $OUTPUT_PATH

# Clean up any existing files in the input and output directories
rm -rf $INPUT_PATH/*
rm -rf $OUTPUT_PATH/*

# Download the file from S3
aws s3 cp "s3://$BUCKET_NAME/$OBJECT_KEY" "$INPUT_PATH/$(basename $OBJECT_KEY)"

# Verify the download
if [ -f "$INPUT_PATH/$(basename $OBJECT_KEY)" ]; then
  echo "File downloaded successfully to $INPUT_PATH"
else
  echo "Failed to download the file from S3"
  exit 1
fi

# Check if the downloaded file is a zip file
FILE_EXTENSION="${OBJECT_KEY##*.}"
if [ "$FILE_EXTENSION" == "zip" ]; then
  echo "The file is a zip file. Unzipping..."
  unzip "$INPUT_PATH/$(basename $OBJECT_KEY)" -d $INPUT_PATH
  rm "$INPUT_PATH/$(basename $OBJECT_KEY)"
  if [ $? -ne 0 ]; then
    echo "Failed to unzip the file"
    exit 1
  fi
fi

# Change ownership of the directories
sudo chown -R ubuntu:ubuntu $INPUT_PATH
sudo chown -R ubuntu:ubuntu $OUTPUT_PATH

# Activate the conda environment
source /home/ubuntu/anaconda3/etc/profile.d/conda.sh
conda activate monai

# Docker login and pull the latest image
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/monai:latest

# Run monai-deploy
monai-deploy run $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/monai:latest -i $INPUT_PATH -o $OUTPUT_PATH

BASE_NAME=$(basename "$OBJECT_KEY" .zip)

# Upload the results to S3 under /results/$BASE_NAME/
aws s3 cp $OUTPUT_PATH s3://$BUCKET_NAME/results/$BASE_NAME/ --recursive

# Upload the input files to S3 under /infered/$BASE_NAME/
aws s3 cp $INPUT_PATH s3://$BUCKET_NAME/infered/$BASE_NAME/ --recursive

# Delete the downloaded file from S3 input bucket
aws s3 rm s3://$BUCKET_NAME/$OBJECT_KEY

# Start the DICOM import job for results
aws medical-imaging start-dicom-import-job \
    --job-name "my-dicom-import-job" \
    --datastore-id "$DATASTORE_ID" \
    --data-access-role-arn "arn:aws:iam::$ACCOUNT_ID:role/service-role/$ROLE_NAME" \
    --input-s3-uri "s3://$BUCKET_NAME/results/$BASE_NAME/" \
    --output-s3-uri "s3://$OUTPUT_BUCKET/$OUTPUT_HEALTHIMAGING_PATH/"

# Start the DICOM import job for infered files
aws medical-imaging start-dicom-import-job \
    --job-name "my-dicom-import-job" \
    --datastore-id "$DATASTORE_ID" \
    --data-access-role-arn "arn:aws:iam::$ACCOUNT_ID:role/service-role/$ROLE_NAME" \
    --input-s3-uri "s3://$BUCKET_NAME/infered/$BASE_NAME/" \
    --output-s3-uri "s3://$BUCKET_NAME/HealthImaging/"

echo "Script execution completed successfully."
