local config = require("config")
local cjson = require("cjson.safe")
local shared = ngx.shared.keys

local function get_active_key()
  local keys = config.API_KEYS
  local now = ngx.now()

  for _ = 1, #keys do
    local new_idx = shared:incr("rr_index", 1, 0)
    if new_idx > 1000000 then
      shared:set("rr_index", 0)
      new_idx = 0
    end
    local idx = (new_idx - 1) % #keys + 1
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
  if not header or header:lower() ~= ("Bearer " .. config.LOCAL_KEY):lower() then
    ngx.status = 401
    ngx.header["Content-Type"] = "application/json"
    ngx.say('{"error":"unauthorized"}')
    ngx.shared.keys:incr("req_401", 1, 0)
    ngx.exit(401)
  end
end

check_auth()

local key = get_active_key()
if not key then
  ngx.status = 503
  ngx.header["Content-Type"] = "application/json"
  ngx.say('{"error":"all keys rate limited"}')
  ngx.shared.keys:incr("req_503", 1, 0)
  ngx.exit(503)
end

ngx.ctx.picked_key = key
ngx.shared.keys:incr("key_rotations", 1, 0)
ngx.req.set_header("Authorization", "Bearer " .. key)

ngx.req.read_body()
local body = ngx.req.get_body_data()
if body then
  local ok, data = pcall(cjson.decode, body)
  if ok and data and data.model then
    ngx.ctx.model = data.model
  else
    io.stderr:write("[proxy] JSON decode failed: " .. tostring(data) .. "\n")
    io.stderr:flush()
  end
end
ngx.ctx.start_time = ngx.now()