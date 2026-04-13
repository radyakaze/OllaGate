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

## Agent Client Configuration

<details>
<summary>Codex</summary>

`~/.codex/config.toml`

```toml
# Disables all user confirmation prompts for actions. Extremely dangerous—remove this setting if you're new to Codex.
# approval_policy = "never"

# Grants unrestricted system access: AI can read/write any file and execute network-enabled commands. Highly risky—remove this setting if you're new to Codex.
# sandbox_mode = "danger-full-access"

model_provider = "ollagate"
model = "glm-5.1" # or any Ollama Cloud model available
model_reasoning_effort = "high"

[model_providers.ollagate]
name = "ollagate"
base_url = "http://127.0.0.1:8080/v1"
wire_api = "responses"
```

`~/.codex/auth.json`

```json
{
  "OPENAI_API_KEY": "my-secret-token"
}
```

</details>

<details>
<summary>OpenCode</summary>

`~/.config/opencode/opencode.jsonc`

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollagate": {
      "name": "OllaGate",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://localhost:8080/v1",
        "apiKey": "my-secret-token"
      },
      "models": {
        "glm-5.1": {
          "name": "GLM 5.1",
          "reasoning": true,
          "limit": {
            "context": 198000,
            "output": 4096
          }
        },
        "kimi-k2.5": {
          "name": "Kimi K2.5",
          "reasoning": true,
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          },
          "limit": {
            "context": 256000,
            "output": 8192
          }
        },
        "minimax-m2.7": {
          "name": "MiniMax M2.7",
          "reasoning": true,
          "limit": {
            "context": 200000,
            "output": 4096
          }
        },
        "gemini-3-flash-preview": {
          "name": "Gemini 3 Flash Lite",
          "reasoning": false,
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          },
          "limit": {
            "context": 1000000,
            "output": 8192
          }
        }
      }
    }
  }
}
```

</details>

## Security

- **Never commit `.env`** — contains secrets
- **Use strong `LOCAL_KEY`** — this is your authentication token
- **Rotate API keys** — if exposed, disable in Ollama dashboard
- **Rate limiting** — protects against abuse (10r/s per IP)
