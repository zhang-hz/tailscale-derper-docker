# Tailscale Derper Docker

A Docker container for Tailscale derper with automatic ACME DNS-01 certificate renewal.

## Features

- Tailscale derper server
- Automatic certificate issuance and renewal via acme.sh
- DNS-01 challenge support (works with many DNS providers)
- Fully configurable via environment variables
- Auto-renewal background process

## Quick Start

1. Copy the example configuration files:
```bash
cp .env.example .env
cp acme.env.example acme.env
```

2. Edit `.env` with your domain and preferences:
```env
DERP_DOMAIN=derp.yourdomain.com
ACME_DNS_PROVIDER=dns_cf
ACME_EMAIL=your@email.com
```

3. Edit `acme.env` with your DNS provider credentials:
```env
CF_Key="your-cloudflare-api-key"
CF_Email="your@email.com"
```

4. Start the container:
```bash
docker-compose up -d
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DERP_DOMAIN` | Your derper domain | - | Yes |
| `DERP_CERT_DIR` | Certificate storage directory | `/app/certs` | No |
| `DERP_STUN_PORT` | STUN port | `3478` | No |
| `DERP_HTTP_PORT` | HTTP port | `80` | No |
| `DERP_HTTPS_PORT` | HTTPS port | `443` | No |
| `DERP_VERIFY_CLIENTS` | Verify Tailscale clients | `false` | No |
| `ACME_DNS_PROVIDER` | DNS provider for acme.sh | - | No |
| `ACME_EMAIL` | Email for ACME account | - | Yes if using ACME |
| `AUTO_RENEW_CERTS` | Enable auto-renewal | `true` | No |
| `RENEW_INTERVAL` | Renew check interval (seconds) | `86400` | No |

### Supported DNS Providers

This container uses acme.sh, which supports many DNS providers. Some common ones:

- `dns_cf` - Cloudflare
- `dns_gd` - GoDaddy
- `dns_ali` - Alibaba Cloud DNS
- `dns_dp` - DNSPod
- `dns_aws` - AWS Route53
- And many more...

See the [acme.sh DNS API documentation](https://github.com/acmesh-official/acme.sh/wiki/dnsapi) for the full list.

## Volumes

- `/app/certs` - Certificate storage (mounted locally to `./certs`)
- `/app/acme.env` - ACME credentials file (mounted read-only)

## Ports

- `80/tcp` - HTTP
- `443/tcp` - HTTPS
- `3478/udp` - STUN

## License

MIT
