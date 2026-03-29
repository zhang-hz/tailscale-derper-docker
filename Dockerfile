FROM alpine:latest

LABEL maintainer="yourname"

ENV DERP_DOMAIN=""
ENV DERP_CERT_DIR="/app/certs"
ENV DERP_STUN_PORT="3478"
ENV DERP_HTTP_PORT="80"
ENV DERP_HTTPS_PORT="443"
ENV DERP_VERIFY_CLIENTS="false"
ENV ACME_DNS_PROVIDER=""
ENV ACME_EMAIL=""
ENV ACME_ENV_FILE=""
ENV AUTO_RENEW_CERTS="true"
ENV RENEW_INTERVAL="86400"

RUN apk add --no-cache \
    ca-certificates \
    curl \
    bash \
    go \
    git \
    tzdata

RUN go install tailscale.com/cmd/derper@latest

RUN curl https://get.acme.sh | sh -s email=$ACME_EMAIL 2>/dev/null || true

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
COPY acme-renew.sh /app/acme-renew.sh

RUN chmod +x /app/entrypoint.sh /app/acme-renew.sh

EXPOSE $DERP_HTTP_PORT/tcp
EXPOSE $DERP_HTTPS_PORT/tcp
EXPOSE $DERP_STUN_PORT/udp

VOLUME ["/app/certs"]

ENTRYPOINT ["/app/entrypoint.sh"]
