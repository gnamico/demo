import boto3
import json
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

region = "us-east-1"
static_instance_id = "i-0e31fd71e53236b01"

ec2 = boto3.client('ec2', region_name=region)
ssm = boto3.client('ssm', region_name=region)


def lambda_handler(event, context):
    try:
        # Extract bucket name and object key from the event
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = event['Records'][0]['s3']['object']['key']
        
        # Use the static instance ID
        instance_id = static_instance_id
        
        # Check the current state of the instance
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance_state = response['Reservations'][0]['Instances'][0]['State']['Name']
        
        if instance_state != 'running':
            # Start EC2 instance
            ec2.start_instances(InstanceIds=[instance_id])
            logger.info('Starting your instance: %s', instance_id)
            
            # Wait until the instance is running
            waiter = ec2.get_waiter('instance_running')
            waiter.wait(InstanceIds=[instance_id])
            logger.info('Instance is now running')
        else:
            logger.info('Instance is already running')
            
        # Update SSM Parameter Store
      #  ssm.put_parameter(
      #      Name='s3_bucket_name',
      #      Value=bucket_name,
      #      Type='String',
      #      Overwrite=True
      #  )
      
      #  ssm.put_parameter(
      #      Name='s3_object_key',
      #      Value=object_key,
      #      Type='String',
      #      Overwrite=True
      #  )
      
      #  logger.info('S3 bucket name and object key stored in SSM Parameter Store')
        
        # Send command to EC2 instance to execute script with arguments
        response = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={
                'commands': [
                    f'sudo su - ubuntu -c "/home/ubuntu/ec2.sh {bucket_name} {object_key}"'
                ]
            }
        )
        logger.info('SSM Run Command sent to instance: %s with bucket: %s and object: %s', instance_id, bucket_name, object_key)
     
        
        return {
            'statusCode': 200,
            'body': json.dumps('SSM parameters updated and command sent to EC2 instance.')
        }
    except Exception as e:
        logger.error('Error: %s', str(e))
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error: {str(e)}")
        }
