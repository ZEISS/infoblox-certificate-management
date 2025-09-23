#!/bin/bash

IFS='.' read -r SUB MAIN <<< "$CERTBOT_DOMAIN"

REQ=$(curl -X GET "$DNS_API_URL?zone=$MAIN&name=_acme-challenge.$SUB&view=Internet" \
     -u "$BASIC_AUTH_USER:$BASIC_AUTH_PASS" \
     -H "EsbApi-Subscription-Key: $ESB_SUBSCRIPTION_KEY")

REF=$(echo "$REQ" | jq -r '.[0]._ref')
echo "cleaning up record $REF"

curl -X DELETE "https://esb.zeiss.com/public/api/infoblox/record?reference=$REF" \
     -u "$BASIC_AUTH_USER:$BASIC_AUTH_PASS" \
     -H "EsbApi-Subscription-Key: $ESB_SUBSCRIPTION_KEY"