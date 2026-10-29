---Format an amount of fluid in L, e.g. 20000000000 -> "20.0G"
---@param value number
---@return string
local function formatAmount(value)
  local units = {"", "k", "M", "G", "T", "P"}
  local unitIndex = 1

  -- 999950 shows as 1.0M, not 1000.0k
  while value >= 999.95 and unitIndex < #units do
    value = value / 1000
    unitIndex = unitIndex + 1
  end

  if unitIndex == 1 then
    return string.format("%.0f", value)
  end

  return string.format("%.1f%s", value, units[unitIndex])
end

return formatAmount
