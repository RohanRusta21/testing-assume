#!/bin/bash

ROLE="arn:aws:iam::577150777926:role/aws-sam-cli-managed-prod-pipe-PipelineExecutionRole-Uje3NfkZXkTn"
SESSION_NAME="testing-stage-packaging"
PROFILE_NAME="testing-stage"
PERMISSIONS_PROVIDER="AWS IAM"
TOKEN=$1
ENV="prod"

unset AWS_SESSION_TOKEN

# Check if required environment variables are set
if [ -z "$PIPELINE_USER_ACCESS_KEY_ID" ] || [ -z "$PIPELINE_USER_SECRET_ACCESS_KEY" ]; then
  echo "Error: AWS credentials environment variables are not set."
  echo "Please set PIPELINE_USER_ACCESS_KEY_ID and PIPELINE_USER_SECRET_ACCESS_KEY."
  exit 1
fi

# Determine environment-specific secret and MFA serial number
if [ "$ENV" == "prod" ]; then
  SECRET=$(jq -r '.SECRET_PROD' config.json)
  MFA_SERIAL_NUMBER=$(jq -r '.MFA_SERIAL_NUMBER_PROD' config.json)
else
  SECRET=$(jq -r '.SECRET' config.json)
  MFA_SERIAL_NUMBER=$(jq -r '.MFA_SERIAL_NUMBER' config.json)
fi

# Ensure jq is available
if ! command -v jq &> /dev/null; then
  echo "jq could not be found. Please install jq."
  exit 1
fi

# Install Node.js and npm (if not already installed)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 14
npm install speakeasy

# Configure AWS CLI profile for the pipeline user
aws configure --profile sam-pipeline-user set aws_access_key_id "$PIPELINE_USER_ACCESS_KEY_ID"
aws configure --profile sam-pipeline-user set aws_secret_access_key "$PIPELINE_USER_SECRET_ACCESS_KEY"

# Generate MFA token
MFA_TOKEN=$(node -e "const speakeasy = require('speakeasy'); console.log(speakeasy.totp({ secret: '$SECRET', encoding: 'base32' }))")
echo "Generated MFA Token: $MFA_TOKEN"

# Get session token with MFA
SESSION_TOKEN=$(aws sts get-session-token --profile sam-pipeline-user --duration-seconds 900 --serial-number "$MFA_SERIAL_NUMBER" --token-code "$MFA_TOKEN" --query 'Credentials')
echo "$SESSION_TOKEN"


if [ -z "$SESSION_TOKEN" ]; then
  echo "Failed to get session token. Please check your AWS credentials and MFA settings."
  exit 1
fi

# Extract AWS credentials from the session token
AWS_ACCESS_KEY_ID=$(echo "$SESSION_TOKEN" | jq -r '.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$SESSION_TOKEN" | jq -r '.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo "$SESSION_TOKEN" | jq -r '.SessionToken')

# Configure AWS CLI for the MFA-enabled session
aws configure --profile "$PROFILE_NAME" set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure --profile "$PROFILE_NAME" set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure --profile "$PROFILE_NAME" set aws_session_token "$AWS_SESSION_TOKEN"

echo "AWS CLI profile '$PROFILE_NAME' configured successfully with MFA session credentials."











# #!/bin/bash
# ROLE="arn:aws:iam::577150777926:role/aws-sam-cli-managed-prod-pipe-PipelineExecutionRole-Uje3NfkZXkTn"
# SESSION_NAME="testing-stage-packaging"
# PROFILE_NAME="testing-stage"
# PERMISSIONS_PROVIDER="AWS IAM"
# TOKEN=$1
# ENV="prod"

# unset AWS_SESSION_TOKEN

# # Determine environment-specific secret and MFA serial number
# if [ "$ENV" == "prod" ]; then
#   SECRET=$(jq -r '.SECRET_PROD' config.json)
#   MFA_SERIAL_NUMBER=$(jq -r '.MFA_SERIAL_NUMBER_PROD' config.json)
# else
#   SECRET=$(jq -r '.SECRET' config.json)
#   MFA_SERIAL_NUMBER=$(jq -r '.MFA_SERIAL_NUMBER' config.json)
# fi

# # Install Node.js and npm (if not already installed)
# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
# source ~/.nvm/nvm.sh
# nvm install 14
# npm install speakeasy

# aws configure --profile sam-pipeline-user set aws_access_key_id "$PIPELINE_USER_ACCESS_KEY_ID"
# aws configure --profile sam-pipeline-user set aws_secret_access_key "$PIPELINE_USER_SECRET_ACCESS_KEY"

# # Generate MFA token
# MFA_TOKEN=$(node -e "const speakeasy = require('speakeasy'); console.log(speakeasy.totp({ secret: '$SECRET', encoding: 'base32' }))")
# echo "$MFA_TOKEN"
# # Get session token with MFA
# SESSION_TOKEN=$(aws sts get-session-token --duration-seconds 900 --serial-number "$MFA_SERIAL_NUMBER" --token-code "$MFA_TOKEN" --query 'Credentials')
# echo "SESSION_TOKEN"

# # Extract AWS credentials from the session token
# AWS_ACCESS_KEY_ID=$(echo "$SESSION_TOKEN" | jq -r '.AccessKeyId')
# AWS_SECRET_ACCESS_KEY=$(echo "$SESSION_TOKEN" | jq -r '.SecretAccessKey')
# AWS_SESSION_TOKEN=$(echo "$SESSION_TOKEN" | jq -r '.SessionToken')

# # Configure AWS CLI for MFA-enabled account
# aws configure --profile sam-pipeline-user set aws_access_key_id "$AWS_ACCESS_KEY_ID"
# aws configure --profile sam-pipeline-user set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
# aws configure --profile sam-pipeline-user set aws_session_token "$AWS_SESSION_TOKEN"

# # Assume the role using the MFA-enabled session credentials
# if [ "$PERMISSIONS_PROVIDER" = "AWS IAM" ]; then
#     cred=$(aws sts assume-role --profile sam-pipeline-user \
#                                 --role-arn "$ROLE" \
#                                 --role-session-name "$SESSION_NAME" \
#                                 --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' \
#                                 --output text)
# else
#     # Use assume-role-with-web-identity if permissions are provided by OIDC
#     cred=$(aws sts assume-role-with-web-identity --role-arn "$ROLE" \
#                                 --role-session-name "$SESSION_NAME" \
#                                 --web-identity-token "$TOKEN" \
#                                 --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' \
#                                 --output text)
# fi

# # Extract assumed role credentials and configure the AWS CLI
# ACCESS_KEY_ID=$(echo "$cred" | awk '{ print $1 }')
# aws configure --profile "$PROFILE_NAME" set aws_access_key_id "$ACCESS_KEY_ID"

# SECRET_ACCESS_KEY=$(echo "$cred" | awk '{ print $2 }')
# aws configure --profile "$PROFILE_NAME" set aws_secret_access_key "$SECRET_ACCESS_KEY"

# SESSION_TOKEN=$(echo "$cred" | awk '{ print $3 }')
# aws configure --profile "$PROFILE_NAME" set aws_session_token "$SESSION_TOKEN"
