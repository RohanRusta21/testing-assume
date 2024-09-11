#!/bin/bash
ROLE=$1
SESSION_NAME=$2
PROFILE_NAME=$3
PERMISSIONS_PROVIDER=$4
TOKEN=$5
ENV=$6

# Load environment-specific values from config.json
if [ "$ENV" == "prod" ]; then
  SECRET=$(jq -r '.SECRET_PROD' config.json)
  MFA_SERIAL_NUMBER=$(jq -r '.MFA_SERIAL_NUMBER_PROD' config.json)
else
  SECRET=$(jq -r '.SECRET' config.json)
  MFA_SERIAL_NUMBER=$(jq -r '.MFA_SERIAL_NUMBER' config.json)
fi

# Install Node.js and npm (if not already installed)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 14
npm install speakeasy

# Define your secret (replace with your Authy secret)
#SECRET=$(jq -r '.SECRET' config.json)
unset AWS_SESSION_TOKEN

# Generate MFA token
TOKEN=$(node -e "const speakeasy = require('speakeasy'); console.log(speakeasy.totp({ secret: '$SECRET', encoding: 'base32' }))")

# Set your MFA serial number and token code MFA_SERIAL_NUMBER="arn:aws:iam::963239714908:mfa/dev-env-mfa"
#MFA_SERIAL_NUMBER=$(jq -r '.MFA_SERIAL_NUMBER' config.json)
SESSION_TOKEN=$(aws sts get-session-token --duration-seconds 900 --serial-number "$MFA_SERIAL_NUMBER" --token-code "$TOKEN")
AWS_ACCESS_KEY_ID=$(echo "$SESSION_TOKEN" | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$SESSION_TOKEN" | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo "$SESSION_TOKEN" | jq -r '.Credentials.SessionToken')

# Set AWS CLI environment variables with the temporary credentials
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

#ACCESS_KEY_ID=$(echo "$cred" | awk '{ print $1 }')
aws configure --profile "$PROFILE_NAME" set aws_access_key_id "$AWS_ACCESS_KEY_ID"

#SECRET_ACCESS_KEY=$(echo "$cred" | awk '{ print $2 }')
aws configure --profile "$PROFILE_NAME" set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

#SESSION_TOKEN=$(echo "$cred" | awk '{ print $3 }')
aws configure --profile "$PROFILE_NAME" set aws_session_token "$AWS_SESSION_TOKEN"
