#!/bin/bash

echo "creating txt record for $DNS_NAME"

certbot certonly \
  --manual \
  -m $CONTACT \
  --preferred-challenges dns \
  --manual-auth-hook ./certbot/auth-hook.sh \
  --manual-cleanup-hook ./certbot/cleanup-hook.sh \
  --work-dir ./certbot/ --config-dir ./certbot/ --logs-dir ./certbot/ \
  --agree-tos --non-interactive \
  -d $DNS_NAME