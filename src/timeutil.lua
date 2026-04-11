-- Time utility functions - safe to require from any context
local _M = {}

function _M.seconds_until_monday_midnight()
  local now = ngx.time()
  local tomorrow = os.date("!*t", now + 86400)
  local days_until = (8 - tomorrow.wday) % 7
  if days_until == 0 then
    days_until = 7
  end
  local t = os.date("!*t", now)
  local seconds_remaining_today = 86400 - (t.hour * 3600 + t.min * 60 + t.sec)
  return seconds_remaining_today + (days_until - 1) * 86400
end

return _M
