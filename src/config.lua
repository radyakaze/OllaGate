local function load_api_keys()
  local keys = {}
  for i = 1, 100 do
    local key = os.getenv("API_KEY_" .. i)
    if key and key ~= "" then
      table.insert(keys, key)
    end
  end
  return keys
end

return {
  API_KEYS = load_api_keys(),
  LOCAL_KEY = os.getenv("LOCAL_KEY") or "my-secret-token",
  RATE_LIMIT_COOLDOWN = tonumber(os.getenv("RATE_LIMIT_COOLDOWN")) or 60,
  METRICS_ENABLED = os.getenv("METRICS_ENABLED") == "true",
}
