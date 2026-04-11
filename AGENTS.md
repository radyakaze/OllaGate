# OLLAGATE - PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-11
**Branch:** main

## OVERVIEW

OpenResty/Nginx gateway for Ollama Cloud with round-robin API key rotation, 429 rate limit protection, local Bearer auth, and environment-based configuration.

## STRUCTURE

```
.
├── src/                    # Core OpenResty modules
│   ├── nginx.conf          # Main nginx config + init blocks
│   ├── proxy.lua           # Auth + key rotation logic
│   ├── metrics.lua         # Prometheus metrics endpoint
│   └── config.lua          # Config loader (reads from env vars)
├── docker-compose.yml      # Dev setup (port 8080)
├── Dockerfile              # Production image build
├── .env.example            # Environment variables template
├── .dockerignore           # Build exclusions (secrets)
├── README.md               # Usage docs
├── logs/                   # Runtime logs (gitignored)
└── tmp/                    # Temp files (gitignored)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add auth logic | `src/proxy.lua` | Bearer check + key rotation |
| Change upstream | `src/nginx.conf` | Modify `proxy_pass` |
| Metrics format | `src/metrics.lua` | Prometheus exposition format |
| Key cooldown config | `.env` | `RATE_LIMIT_COOLDOWN` env var |
| Add new API key | `.env` | Add `API_KEY_N` (up to 100) |
| Docker setup | `docker-compose.yml` | Volume mounts from `src/` |

## CONFIGURATION

Configuration is loaded from **environment variables** via `.env` file:

```bash
# .env
API_KEY_1=your-key-1
API_KEY_2=your-key-2
# ... up to API_KEY_100
LOCAL_KEY=my-secret-token
RATE_LIMIT_COOLDOWN=60
METRICS_ENABLED=false
```

The `src/config.lua` reads these env vars at runtime.

## CODE MAP

| Symbol | Type | File | Role |
|--------|------|------|------|
| `load_api_keys()` | function | `config.lua` | Load API_KEY_* from env vars |
| `get_active_key()` | function | `proxy.lua` | Round-robin key picker with cooldown check |
| `check_auth()` | function | `proxy.lua` | Bearer token validation |
| `ngx.shared.keys` | dict | `nginx.conf` | Shared memory: counters, disabled keys, rotation state |
| `/v1` | location | `nginx.conf` | Main proxy endpoint |
| `/health` | location | `nginx.conf` | Health check endpoint |
| `/metrics` | location | `nginx.conf` | Prometheus metrics endpoint |
| `init_by_lua_block` | block | `nginx.conf` | Init counters (200, 401, 429, 503, rotations) |
| `init_worker_by_lua_block` | block | `nginx.conf` | Reset round-robin index, clear disabled keys |
| `log_by_lua_block` | block | `nginx.conf` | Log model + latency + key prefix |

## CONVENTIONS

- **Environment config**: All settings via `.env`, loaded by `config.lua`
- **Lua modules**: Use `require("cjson.safe")` for safe JSON decode
- **Shared dict**: Always use `ngx.shared.keys` for state
- **Key masking**: Log only first 8 chars (`string.sub(key, 1, 8).."..."`)
- **Time format**: Smart formatting (`>1s` show as seconds, `<1s` as ms)

## ANTI-PATTERNS

- **NEVER** commit `.env` (contains secrets) — use `.env.example` as template
- **NEVER** commit `src/config.lua` with hardcoded keys — env vars only
- **NEVER** use `io.stdout:write` in log blocks — use `io.stderr:write` + `flush()`
- **NEVER** disable `proxy_buffering` without reason — required for streaming
- **AVOID** hardcoding paths in Lua — use `lua_package_path` in nginx.conf

## UNIQUE STYLES

- **Environment-based config**: API keys loaded from env vars (API_KEY_1 to API_KEY_100)
- **Round-robin with cooldown**: Keys auto-disable on 429, re-enable after `RATE_LIMIT_COOLDOWN`
- **Rate limiting**: 10r/s per IP with burst 20
- **Streaming support**: `proxy_buffering off` + HTTP/1.1 for SSE compatibility
- **Model extraction**: Parse request body in `log_by_lua_block` to capture model name

## COMMANDS

```bash
# Dev (with hot reload via volume mounts)
docker compose up -d

# Production build
docker build -t ollagate .
docker run -p 8080:80 \
  -e API_KEY_1="xxx" \
  -e LOCAL_KEY="secret" \
  -e RATE_LIMIT_COOLDOWN=60 \
  ollagate

# Test health
curl http://localhost:8080/health

# Test metrics
curl http://localhost:8080/metrics

# Test proxy (requires valid LOCAL_KEY)
curl -H "Authorization: Bearer $LOCAL_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model":"llama2","messages":[{"role":"user","content":"hi"}]}' \
     http://localhost:8080/v1/chat/completions
```

## NOTES

- `src/` folder is mounted to `/usr/local/openresty/nginx/conf/` in container
- `config.lua` reads env vars at runtime via `os.getenv()`
- Rate limit cooldown configured via `RATE_LIMIT_COOLDOWN` env var
- Logs go to stderr for Docker compatibility
- `/metrics` can be disabled via `METRICS_ENABLED=false` in `.env`
