local ngx = ngx
local shared = ngx.shared.keys
local config = require("config")

if config.METRICS_ENABLED == false then
  ngx.status = 404
  ngx.say("Not Found")
  ngx.exit(404)
end

local function get_counter(name)
  local val, _ = shared:get(name)
  return val or 0
end

local metrics = {}

-- Request counter by status
table.insert(metrics, '# HELP ollagate_requests_total Total requests by status code')
table.insert(metrics, '# TYPE ollagate_requests_total counter')
for _, code in ipairs({200, 401, 429, 503}) do
  local val = get_counter("req_" .. code)
  table.insert(metrics, string.format('ollagate_requests_total{status="%s"} %d', code, val))
end

-- Active keys gauge
table.insert(metrics, '')
table.insert(metrics, '# HELP ollagate_active_keys Number of active (non-rate-limited) API keys')
table.insert(metrics, '# TYPE ollagate_active_keys gauge')
local active_keys = 0
local total_keys = #config.API_KEYS
for _, key in ipairs(config.API_KEYS) do
  local disabled = shared:get("disabled:" .. key)
  if not disabled then
    active_keys = active_keys + 1
  end
end
table.insert(metrics, string.format('ollagate_active_keys %d', active_keys))

-- Total keys gauge
table.insert(metrics, '')
table.insert(metrics, '# HELP ollagate_total_keys Total number of configured API keys')
table.insert(metrics, '# TYPE ollagate_total_keys gauge')
table.insert(metrics, string.format('ollagate_total_keys %d', total_keys))

-- Rate limited keys gauge
table.insert(metrics, '')
table.insert(metrics, '# HELP ollagate_rate_limited_keys Number of currently rate-limited keys')
table.insert(metrics, '# TYPE ollagate_rate_limited_keys gauge')
table.insert(metrics, string.format('ollagate_rate_limited_keys %d', total_keys - active_keys))

-- Key rotation counter
table.insert(metrics, '')
table.insert(metrics, '# HELP ollagate_key_rotations_total Total key rotations')
table.insert(metrics, '# TYPE ollagate_key_rotations_total counter')
table.insert(metrics, string.format('ollagate_key_rotations_total %d', get_counter("key_rotations")))

-- Uptime (approximate from nginx start)
table.insert(metrics, '')
table.insert(metrics, '# HELP ollagate_uptime_seconds Nginx uptime in seconds')
table.insert(metrics, '# TYPE ollagate_uptime_seconds gauge')
table.insert(metrics, string.format('ollagate_uptime_seconds %d', ngx.time() - ngx.worker.start_time()))

ngx.header["Content-Type"] = "text/plain; charset=utf-8"
ngx.say(table.concat(metrics, "\n"))
