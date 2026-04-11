# OLLAGATE - PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-11
**Commit:** bdda2fa
**Branch:** main

## OVERVIEW

OpenResty/Nginx gateway for Ollama Cloud with round-robin API key rotation, 429 rate limit protection, and local Bearer auth.

## STRUCTURE

```
.
├── src/                    # Core OpenResty modules
│   ├── nginx.conf          # Main nginx config + init blocks
│   ├── proxy.lua            # Auth + key rotation logic
│   └── metrics.lua          # Prometheus metrics endpoint
├── config.lua               # Runtime config (API keys, LOCAL_KEY)
├── config.lua.example       # Template for config.lua
├── docker-compose.yml       # Dev setup (port 8080)
├── Dockerfile               # Production image build
├── README.md                # Usage docs
├── logs/                    # Runtime logs (gitignored)
└── tmp/                     # Temp files (gitignored)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add auth logic | `src/proxy.lua` | Bearer check + key rotation |
| Change upstream | `src/nginx.conf:43` | Modify `proxy_pass` |
| Metrics format | `src/metrics.lua` | Prometheus exposition format |
| Key cooldown config | `config.lua` | `RATE_LIMIT_COOLDOWN` |
| Add new API key | `config.lua` | Add to `API_KEYS` array |
| Docker setup | `docker-compose.yml` | Volume mounts from `src/` |

## CODE MAP

| Symbol | Type | File | Role |
|--------|------|------|------|
| `get_active_key()` | function | `proxy.lua:5` | Round-robin key picker with cooldown check |
| `check_auth()` | function | `proxy.lua:29` | Bearer token validation |
| `ngx.shared.keys` | dict | `nginx.conf:9` | Shared memory: counters, disabled keys, rotation state |
| `/v1` | location | `nginx.conf:35` | Main proxy endpoint |
| `/metrics` | location | `nginx.conf:86` | Prometheus metrics endpoint |
| `init_by_lua_block` | block | `nginx.conf:11` | Init counters (200, 401, 429, 503, rotations) |
| `init_worker_by_lua_block` | block | `nginx.conf:22` | Reset round-robin index, clear disabled keys |
| `log_by_lua_block` | block | `nginx.conf:45` | Log model + latency + key prefix |

## CONVENTIONS

- **Lua modules**: Use `require("cjson.safe")` for safe JSON decode
- **Shared dict**: Always use `ngx.shared.keys` for state
- **Key masking**: Log only first 8 chars (`string.sub(key, 1, 8).."..."`)
- **Time format**: Smart formatting (`>1s` show as seconds, `<1s` as ms)
- **Config pattern**: `config.lua` returns table, loaded by both nginx init and Lua

## ANTI-PATTERNS

- **NEVER** commit `config.lua` (contains secrets) — use `config.lua.example`
- **NEVER** use `io.stdout:write` in log blocks — use `io.stderr:write` + `flush()`
- **NEVER** disable `proxy_buffering` without reason — required for streaming
- **AVOID** hardcoding paths in Lua — use `lua_package_path` in nginx.conf

## UNIQUE STYLES

- **Round-robin with cooldown**: Keys auto-disable on 429, re-enable after `RATE_LIMIT_COOLDOWN`
- **Streaming support**: `proxy_buffering off` + HTTP/1.1 for SSE compatibility
- **Model extraction**: Parse request body in `log_by_lua_block` to capture model name

## COMMANDS

```bash
# Dev (with hot reload via volume mounts)
docker compose up -d

# Production build
docker build -t ollagate .
docker run -p 8080:80 ollagate

# Test metrics
curl http://localhost:8080/metrics

# Test proxy (requires valid LOCAL_KEY)
curl -H "Authorization: Bearer $LOCAL_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model":"llama2","messages":[{"role":"user","content":"hi"}]}' \
     http://localhost:8080/v1/chat/completions
```

## NOTES

- `config.lua` is mounted at `/app/config.lua` in container
- Lua modules use `/app/?.lua` + `/usr/local/openresty/nginx/conf/?.lua` in path
- Rate limit cooldown: 300s hardcoded in nginx.conf (should match config.lua)
- Logs go to stderr for Docker compatibility
- `/metrics` can be disabled via `METRICS_ENABLED = false` in config.lua
