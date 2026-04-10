local config = require("config")
local shared = ngx.shared.keys

local function get_active_key()
  local keys = config.API_KEYS
  local now = ngx.now()

  for _ = 1, #keys do
    local idx = (shared:incr("rr_index", 1, 0) - 1) % #keys + 1
    local key = keys[idx]
    local disabled_at = shared:get("disabled:" .. key)
    if not disabled_at or (now - disabled_at) >= config.RATE_LIMIT_COOLDOWN then
      if disabled_at then
        shared:delete("disabled:" .. key)
      end
      return key
    end
  end

  return nil
end

local function check_auth()
  local header = ngx.req.get_headers()["Authorization"]
  if not header or header ~= "Bearer " .. config.LOCAL_KEY then
    ngx.status = 401
    ngx.header["Content-Type"] = "application/json"
    ngx.say('{"error":"unauthorized"}')
    ngx.exit(401)
  end
end

check_auth()

local key = get_active_key()
if not key then
  ngx.status = 503
  ngx.header["Content-Type"] = "application/json"
  ngx.say('{"error":"all keys rate limited"}')
  ngx.exit(503)
end

ngx.ctx.picked_key = key
ngx.req.set_header("Authorization", "Bearer " .. key)