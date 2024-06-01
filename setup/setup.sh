#!/bin/bash

# Variables
FUNCTION_NAME=""
ROLE_ARN=""
REGION=""
BUCKET_NAME=""
ACCOUNT_ID=""

# Zip the Lambda function code
zip -r function.zip lambda_function.py

# Create or update the Lambda function
aws lambda create-function --function-name $FUNCTION_NAME \
--zip-file fileb://function.zip --handler lambda_function.lambda_handler \
--runtime python3.8 --role $ROLE_ARN --region $REGION \
|| \
aws lambda update-function-code --function-name $FUNCTION_NAME \
--zip-file fileb://function.zip --region $REGION

# Add S3 bucket permissions to invoke the Lambda function
aws lambda add-permission --function-name $FUNCTION_NAME --statement-id S3Invoke --action lambda:InvokeFunction --principal s3.amazonaws.com --source-arn arn:aws:s3:::$BUCKET_NAME

# Create S3 event configuration JSON
cat <<EOT > s3_event_configuration.json
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION_NAME",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "input/"
            }
          ]
        }
      }
    }
  ]
}
EOT

# Apply the S3 event configuration
aws s3api put-bucket-notification-configuration --bucket $BUCKET_NAME --notification-configuration file://s3_event_configuration.json

echo "Lambda function and S3 event notification configured successfully."
