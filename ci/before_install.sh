#!/usr/bin/env bash

set -o errexit
set -o pipefail

# Extract AWS credentials file so we can use AWS stuff without exporting access key/secret
mkdir -p ~/.aws && echo ${AWS_CREDENTIALS_FILE} | base64 -d > ~/.aws/credentials
