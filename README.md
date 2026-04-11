# OllaGate

OpenResty/Nginx gateway for Ollama Cloud with multi-key rotation, rate limit protection, and local auth.

## Features

- **Round-robin** API key rotation
- **Auto-disable** keys on 429 rate limit, re-enable after cooldown
- **Weekly usage limit cooldown** — disable key until next Monday 00:00 UTC on "weekly usage limit" error
- **Streaming** support (zero buffering)
- **Local auth** with Bearer token
- **Rate limiting** (10r/s with burst 20)
- **Prometheus metrics** endpoint

## Quick Start

### Option 1: Using Pre-built Image (No Clone Required)

```bash
# 1. Create .env file
cat > .env << 'EOF'
API_KEY_1=your-ollama-key-1
API_KEY_2=your-ollama-key-2
LOCAL_KEY=my-secret-token
RATE_LIMIT_COOLDOWN=60
METRICS_ENABLED=false
EOF

# 2. Run directly from Docker Hub
docker run -d \
  --name ollagate \
  -p 8080:80 \
  --env-file .env \
  --restart unless-stopped \
  ghcr.io/radyakaze/ollagate
```

### Option 2: Clone and Run Locally

```bash
# 1. Clone repository
git clone https://github.com/radyakaze/OllaGate.git
cd OllaGate

# 2. Copy environment template
cp .env.example .env

# 3. Edit .env — add your API keys and set LOCAL_KEY
# API_KEY_1=your-key-1
# API_KEY_2=your-key-2
# ...
# LOCAL_KEY=my-secret-token

# 4. Run
docker compose up -d
```

## Configuration

Edit `.env`:

```bash
# API Keys for Ollama Cloud (up to 100 keys)
API_KEY_1=sk-xxx1
API_KEY_2=sk-xxx2
API_KEY_3=sk-xxx3
# ...

# Local authentication token
LOCAL_KEY=my-secret-token

# Rate limit cooldown in seconds
RATE_LIMIT_COOLDOWN=60

# Enable Prometheus metrics endpoint
METRICS_ENABLED=false

# Enable weekly usage limit cooldown mode
WEEKLY_LIMIT_COOLDOWN_MODE=true
```

| Variable | Description | Default |
|----------|-------------|---------|
| `API_KEY_N` | Upstream Ollama Cloud API keys (1-100) | - |
| `LOCAL_KEY` | Bearer token for local auth | `my-secret-token` |
| `RATE_LIMIT_COOLDOWN` | Seconds before a 429'd key is re-enabled | 60 |
| `METRICS_ENABLED` | Enable `/metrics` endpoint | false |
| `WEEKLY_LIMIT_COOLDOWN_MODE` | Enable weekly limit cooldown mode | true |

## Development

```bash
# Run locally (mounts src/ for hot reload)
docker compose up -d

# View logs
docker compose logs -f

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

## Architecture

```
Client → Auth check → Rate limit check → Round-robin pick key → Proxy to Ollama Cloud
                                                                     ↓
                                                               Response 429?
                                                               → Disable key + cooldown
```

## Project Structure

```
.
├── src/
│   ├── nginx.conf          # Main nginx config
│   ├── proxy.lua           # Auth + key rotation
│   ├── metrics.lua         # Prometheus metrics
│   └── config.lua          # Config loader (reads env vars)
├── docker-compose.yml      # Dev setup
├── Dockerfile              # Production build
├── .env.example            # Environment template
└── .dockerignore           # Build exclusions
```

## Security

- **Never commit `.env`** — contains secrets
- **Use strong `LOCAL_KEY`** — this is your authentication token
- **Rotate API keys** — if exposed, disable in Ollama dashboard
- **Rate limiting** — protects against abuse (10r/s per IP)
