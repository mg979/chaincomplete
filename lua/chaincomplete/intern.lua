local M = {}

-- translate triggers to patterns:
-- keyword character followed by escaped trigger chars
local function make_pats(triggers)
  if type(triggers) ~= 'table' then
    return nil
  end
  local trigpats = {}
  for ft, trigs in pairs(triggers) do
    trigpats[ft] = {}
    for ix, chars in ipairs(trigs) do
      trigpats[ft][ix] = '[_%w]' .. chars:gsub('(%p)', '%%%1')
    end
  end
  return trigpats
end

local default_triggers = {
  ['lua'] = { '.', ':' },
}

M.noselect = false

M.autocomplete = {
  enabled = false,
  prefix = 3,
  triggers = default_triggers,
}

M.border = {
  style = {},
  row = 3,
  col = 3
}

M.docinfo = {}
M.signature = {}
M.use_hover = {}
M.resolve_documentation = {}

-------------------------------------------------------------------------------

--- Settings for autocompletion.
function M.set_autocomplete_opts(ac)
  local a = M.autocomplete
  if type(ac) ~= 'table' then
    a.enabled = ac or false
    a.prefix = ac == 'triggers' and false or 3
  else
    a.enabled = ac.enabled or false
    a.prefix = ac.prefix
    a.triggers = ac.triggers
    if type(a.triggers) == 'table' then
      if a.triggers[1] then
        -- list-like: all filetypes use the same
        a.triggers = {['*'] = a.triggers}
      end
    end
  end
  a.trigpats = make_pats(a.triggers)
  return {
    enabled = a.enabled,
    prefix = a.prefix,
    triggers = a.triggers
  }
end

-------------------------------------------------------------------------------

--- Settings for popup border.
function M.set_border_opts(border)
  local b = M.border
  b.style = border
  if type(border) == 'table' then
    b.row = string.len(border[2])
    b.col = string.len(border[4])
  elseif border == 'sides' then
    b.style = { '', '', '', ' ', '', '', '', ' ' }
    b.row = 1
    b.col = 3
  elseif border == 'none' then
    b.row = 1
    b.col = 1
  else
    b.row = 3
    b.col = 3
  end
end

-------------------------------------------------------------------------------

-- Set internal setting for various options.
function M.set_opt(opt, value)
  if not M[opt] then
    print('[chaincomplete] invalid option:', opt)
    return
  end
  local O = M[opt]
  if type(value) == 'table' then -- using tables with filetypes
    if #value > 0 then    -- list-like
      for _, ft in ipairs(value) do
        O[ft] = true
      end
    else
      for ft, v in pairs(value) do
        O[ft] = v
      end
    end
  else
    M[opt] = {['*'] = value or false}
  end
end

-------------------------------------------------------------------------------

--- Get internal setting for filetype.
---@param opt string option name
---@param ft string filetype
---@return any: option value
function M.get_opt(opt, ft)
    return M[opt][ft] or (M[opt]['*'] and M[opt][ft] ~= false)
end

-------------------------------------------------------------------------------

return M
