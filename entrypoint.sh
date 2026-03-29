#!/bin/bash

set -e

if [ -z "$DERP_DOMAIN" ]; then
    echo "ERROR: DERP_DOMAIN environment variable is required"
    exit 1
fi

mkdir -p "$DERP_CERT_DIR"

if [ ! -z "$ACME_DNS_PROVIDER" ]; then
    if [ -z "$ACME_EMAIL" ]; then
        echo "ERROR: ACME_EMAIL is required when using ACME_DNS_PROVIDER"
        exit 1
    fi

    if [ -f "$ACME_ENV_FILE" ]; then
        echo "Loading ACME environment variables from $ACME_ENV_FILE"
        export $(grep -v '^#' "$ACME_ENV_FILE" | xargs)
    fi

    echo "Setting up ACME.sh with DNS provider: $ACME_DNS_PROVIDER"
    
    if [ ! -f "/root/.acme.sh/acme.sh" ]; then
        echo "Installing acme.sh..."
        curl https://get.acme.sh | sh -s email="$ACME_EMAIL"
    fi

    export PATH="/root/.acme.sh:$PATH"

    CERT_PATH="$DERP_CERT_DIR/$DERP_DOMAIN.crt"
    KEY_PATH="$DERP_CERT_DIR/$DERP_DOMAIN.key"

    if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
        echo "Issuing certificate for $DERP_DOMAIN..."
        /root/.acme.sh/acme.sh --issue --dns "$ACME_DNS_PROVIDER" -d "$DERP_DOMAIN" \
            --cert-file "$CERT_PATH" \
            --key-file "$KEY_PATH" \
            --fullchain-file "$CERT_PATH"
    else
        echo "Certificate already exists, checking if renewal is needed..."
        /root/.acme.sh/acme.sh --renew -d "$DERP_DOMAIN" \
            --cert-file "$CERT_PATH" \
            --key-file "$KEY_PATH" \
            --fullchain-file "$CERT_PATH" || true
    fi

    if [ "$AUTO_RENEW_CERTS" = "true" ]; then
        echo "Starting certificate auto-renewal background process..."
        /app/acme-renew.sh &
    fi
fi

DERPER_ARGS=""
DERPER_ARGS="$DERPER_ARGS -a :$DERP_HTTP_PORT"
DERPER_ARGS="$DERPER_ARGS -http-port $DERP_HTTP_PORT"

if [ -f "$DERP_CERT_DIR/$DERP_DOMAIN.crt" ] && [ -f "$DERP_CERT_DIR/$DERP_DOMAIN.key" ]; then
    DERPER_ARGS="$DERPER_ARGS -certmode manual"
    DERPER_ARGS="$DERPER_ARGS -certdir $DERP_CERT_DIR"
    DERPER_ARGS="$DERPER_ARGS -hostname $DERP_DOMAIN"
else
    DERPER_ARGS="$DERPER_ARGS -certmode automatic"
fi

if [ "$DERP_VERIFY_CLIENTS" = "true" ]; then
    DERPER_ARGS="$DERPER_ARGS -verify-clients"
fi

if [ ! -z "$DERP_STUN_PORT" ]; then
    DERPER_ARGS="$DERPER_ARGS -stun-port $DERP_STUN_PORT"
fi

echo "Starting derper with args: $DERPER_ARGS"
exec /root/go/bin/derper $DERPER_ARGS
