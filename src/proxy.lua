local config = require("config")
local cjson = require("cjson.safe")
local shared = ngx.shared.keys

local _M = {}

function _M.get_active_key()
  local keys = config.API_KEYS
  local key_count = #keys
  if key_count == 0 then
    return nil
  end

  local new_idx = shared:incr("rr_index", 1, 0)
  local idx = ((new_idx - 1) % key_count) + 1
  local start_idx = idx

  repeat
    local key = keys[idx]
    if not shared:get("disabled:" .. key) then
      return key
    end
    idx = (idx % key_count) + 1
  until idx == start_idx

  return nil
end

function _M.check_auth()
  local header = ngx.req.get_headers()["Authorization"]
  if not header or header:lower() ~= ("Bearer " .. config.LOCAL_KEY):lower() then
    ngx.status = 401
    ngx.header["Content-Type"] = "application/json"
    ngx.say('{"error":"unauthorized"}')
    ngx.shared.keys:incr("req_401", 1, 0)
    return ngx.exit(401)
  end
end

return _M