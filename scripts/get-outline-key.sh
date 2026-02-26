#!/bin/bash

echo "Checking required variables"
: "${API_URL:?Missing API_URL}"
: "${KEY_NAME:?Missing KEY_NAME}"

curl -k -s -X POST "$API_URL/access-keys" > ${KEY_NAME}.json
ID=$(jq -r '.id' ${KEY_NAME}.json)

curl -k -s -X PUT "$API_URL/access-keys/$ID/name" \
	-d "name=$KEY_NAME"

KEY=$(jq -r '.accessUrl' ${KEY_NAME}.json)

echo $KEY
