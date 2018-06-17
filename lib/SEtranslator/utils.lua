--- @module utils
local utils = {}

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function tprint(tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
      print(formatting .. v)
    end
  end
end



function has_value(tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return true
    end
  end

  return false
end

function stringExplode(s,sep)
  local output = {}
  if sep == nil then
    sep = "%s"
  end
  for match in s:gmatch("([^"..sep.."%s]+)") do
    output[#output + 1] = match
  end
  return output
end

utils.stringExplode = stringExplode
utils.has_value = has_value
utils.tprint = tprint

return utils
