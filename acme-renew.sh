#!/bin/bash

set -e

RENEW_INTERVAL=${RENEW_INTERVAL:-86400}

echo "Certificate auto-renewal daemon started (interval: $RENEW_INTERVAL seconds)"

while true; do
    sleep "$RENEW_INTERVAL"
    
    echo "[$(date)] Checking certificate renewal..."
    
    if [ -n "$DERP_DOMAIN" ]; then
        CERT_PATH="$DERP_CERT_DIR/$DERP_DOMAIN.crt"
        KEY_PATH="$DERP_CERT_DIR/$DERP_DOMAIN.key"
        
        /root/.acme.sh/acme.sh --renew -d "$DERP_DOMAIN" \
            --cert-file "$CERT_PATH" \
            --key-file "$KEY_PATH" \
            --fullchain-file "$CERT_PATH" || true
    fi
done
