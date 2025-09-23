#!/bin/bash

DOMAIN="_acme-challenge.${CERTBOT_DOMAIN}"
TOKEN="$CERTBOT_VALIDATION"

echo "creating record $DOMAIN with value $TOKEN"

REF=$(curl -X POST "$DNS_API_URL" \
     -u "$BASIC_AUTH_USER:$BASIC_AUTH_PASS" \
     -H "EsbApi-Subscription-Key: $ESB_SUBSCRIPTION_KEY" \
     -H "Content-Type: application/json" \
     -d "{\"name\": \"$DOMAIN\", \"text\": \"$TOKEN\", \"view\": \"Internet\"}") 

echo "recrod $REF created"
echo "sleeping 60 seconds"
sleep 60