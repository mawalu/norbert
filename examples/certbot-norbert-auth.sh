#!/bin/sh

API_USER=""
API_KEY=""

curl -s --request POST \
  --url http://10.200.100.10:18000/present \
  --header 'Content-Type: application/json' \
  --user "$API_USER:$API_KEY" \
  --data "{\"fqdn\": \"$CERTBOT_DOMAIN\", \"value\": \"$CERTBOT_VALIDATION\"}"
