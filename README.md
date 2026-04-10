# OllaGate

OpenResty gateway for Ollama Cloud with multi-key rotation, rate limit protection, and local auth.

## Features

- **Round-robin** API key rotation
- **Auto-disable** keys on 429 rate limit, re-enable after cooldown
- **Streaming** support (zero buffering)
- **Local auth** with Bearer token

## Setup

```bash
cp config.lua.example config.lua
# Edit config.lua — add your API keys and set LOCAL_KEY
docker compose up -d
```

## Configuration

Edit `config.lua`:

```lua
return {
  API_KEYS = {
    "sk-xxx1",
    "sk-xxx2",
  },
  LOCAL_KEY = "my-secret-token",
  RATE_LIMIT_COOLDOWN = 60,
}
```

| Key                  | Description                            |
| -------------------- | -------------------------------------- |
| `API_KEYS`           | List of upstream Ollama Cloud API keys |
| `LOCAL_KEY`          | Bearer token for local auth            |
| `RATE_LIMIT_COOLDOWN`| Seconds before a 429'd key is re-enabled |

Modify `proxy_pass` in `nginx.conf` to change the upstream URL.

## Architecture

```
Client → Auth check → Round-robin pick key → Proxy to Ollama Cloud
                                                ↓
                                          Response 429?
                                          → Disable key + cooldown
```
