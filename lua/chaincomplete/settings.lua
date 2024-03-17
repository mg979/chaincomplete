local fn = vim.fn
local api, _, tbl, arr = require("nvim-lib")()
local lsp = require('chaincomplete.lsp')

-------------------------------------------------------------------------------
-- Default settings
-------------------------------------------------------------------------------

local DEFAULT = {
  autocomplete = {
    enabled = false,
    prefix = 3,
    triggers = { lua = { '.', ':' } },
  },
  info = {
    use_hover = { ['*'] = true, go = false },
    border = { ['*'] = 'solid', cs = 'solid' },
    width = 80,
    height = 25,
  },
  signature = {
    border = 'solid',
    width = 80,
    height = 25,
  },
  chain_lsp = { 'lsp', 'files', 'user', 'c-n' },
  chain_nolsp = { 'omni', 'files', 'user', 'c-n' },
  process_items = lsp.process_items,
  lsp_fuzzy = false,
  fuzzy_minchars = 2,
}

-- Initialized in setup().
local SETTINGS

-- Used internally by the plugin.
local PRIVATE = {
  noselect = false,
  menuone = false,
}

-------------------------------------------------------------------------------
--- Default chain for current buffer.
--- @return table chain
local function DefaultChain()
  if vim.o.omnifunc == 'v:lua.vim.lsp.omnifunc' then
    return tbl.copy(SETTINGS.chain_lsp)
  end
  for _, client in pairs(lsp.get_clients()) do
    if client.server_capabilities.completionProvider then
      return tbl.copy(SETTINGS.chain_lsp)
    end
  end
  return tbl.copy(SETTINGS.chain_nolsp)
end

-------------------------------------------------------------------------------
--- Generate table representation for various options.
--- This is used to have filetype-specific behaviours for each option.
--- `value` can translate in several ways:
---
---   non-table: all filetypes use the same value
---     -> {['*'] = value}
---
---   array: each element is considered TRUE
---     -> { value[1] = true, value[2] = true, ... }
---
---   pairs: unchanged
---
---@param value any
---@return table
local function NormalizeSetting(value, ft)
  -- {{{1
  local o = {}
  if type(value) == 'table' then
    for k, v in pairs(value) do
      if type(k) == 'number' then
        o[v] = true
      else
        o[k] = v
      end
    end
  else
    o = { [ft or '*'] = value or false }
  end
  return o
end
-- }}}

-------------------------------------------------------------------------------
--- Retrieve a filetype-specific setting, to be used by a chain.
---@param value any: the value from settings
---@param ft string: the filetype
---@return any
local function GetFtOpt(value, ft)
  -- {{{1
  if type(value) == 'table' then -- '*' is the fallback, not always present
    return value[ft] or arr.indexof(value, ft) or value['*']
  else
    return value
  end
end
-- }}}

-------------------------------------------------------------------------------
--- Generate settings for a buffer-local chain.
--- Some vim options values are cached to avoid that they are evaluated at every
--- completion attempt. The chain is generated only once per buffer, though, so
--- some events will have to invalidate the chain, and this configuration will
--- be updated.
---@return table
local function MakeChainSettings(buf)
  -- {{{1
  buf = buf or fn.bufnr()
  local ft, s, opt = api.buf_get_option(buf, 'filetype'), SETTINGS, GetFtOpt
  local o = {
    autocomplete = opt(s.autocomplete.enabled, ft),
    prefix = opt(s.autocomplete.prefix, ft),
    triggers = opt(s.autocomplete.triggers, ft),
    info = s.info and {
      use_hover = opt(s.info.use_hover, ft)
        and lsp.has_capability('hoverProvider'),
      width = opt(s.info.width, ft),
      height = opt(s.info.height, ft),
      border = opt(s.info.border, ft),
    },
    signature = s.signature and {
      width = opt(s.signature.width, ft),
      height = opt(s.signature.height, ft),
      border = opt(s.signature.border, ft),
    },
    omni = vim.o.omnifunc ~= '',
    tags = vim.o.tagfunc ~= '' or next(vim.fn.tagfiles()),
    thesaurus = vim.o.thesaurus ~= '' or vim.o.thesaurusfunc ~= '',
    dict = vim.o.dictionary ~= '',
    cfunc = vim.o.completefunc ~= '',
    lsp = lsp.get_buf_client(buf) ~= nil,
    lsp_triggers = lsp.completion_triggers(buf),
  }
  -- o.triggers can be just `true`, in this case lsp triggers will be used.
  -- Otherwise, generate trigger patterns, will be used to match the trigger
  -- themselves, it's done beforehand to make it faster during completion.
  -- Patterns are keyword character followed by escaped trigger chars.
  if type(o.triggers) == 'table' then
    o.trigpats = {}
    local pre = o.prefix == 1 and '' or '[_%w]'
    for ix, chars in ipairs(o.triggers) do
      o.trigpats[ix] = pre .. chars:gsub('(%p)', '%%%1')
    end
  end
  return o
end
-- }}}

-------------------------------------------------------------------------------
--- Update settings for autocompletion from given table.
---@param opts table
---@return table
local function MakeAutocompleteOpts(opts)
  -- {{{1
  local ac = SETTINGS.autocomplete
  assert(
    not opts or not opts.triggers or type(opts.triggers) == 'table',
    "'triggers' must be a table"
  )
  for k, v in pairs(ac) do
    ac[k] = NormalizeSetting(v)
  end
  -- print('opts = ' .. vim.inspect(opts))
  for k in pairs(ac) do
    tbl.merge(ac[k], opts[k])
  end
  return ac
end
-- }}}

-------------------------------------------------------------------------------
--- Set or restore default options.
local function SetDefaults()
  SETTINGS = {}
  for k, v in pairs(DEFAULT) do
    SETTINGS[k] = type(v) == 'table' and tbl.deepcopy(v) or v
  end
  for k, v in pairs(SETTINGS.autocomplete) do
    SETTINGS.autocomplete[k] = NormalizeSetting(v)
  end
end

-------------------------------------------------------------------------------
--- Print current settings.
local function PrintSettings()
  -- {{{1
  local s = SETTINGS
  print('settings = ' .. vim.inspect({
    autocomplete = {
      enabled = s.autocomplete.enabled or false,
      prefix = s.autocomplete.prefix,
      triggers = s.autocomplete.triggers,
    },
    info = s.info or false,
    signature = s.signature or false,
    chain_lsp = s.chain_lsp,
    chain_nolsp = s.chain_nolsp,
  }))
end
-- }}}

-------------------------------------------------------------------------------
--- Print current autocomplete settings.
local function PrintAutocomplete()
  -- {{{1
  local ac = SETTINGS.autocomplete
  print('autocomplete = ' .. vim.inspect({
    enabled = ac.enabled,
    prefix = ac.prefix,
    triggers = ac.triggers,
  }))
end
-- }}}

-------------------------------------------------------------------------------

SetDefaults()

return {
  -----------------------------------------------------------------------------
  --- Setup function.
  ---@param opts table
  setup = function(opts)
    opts = opts or vim.g.chaincomplete or {}
    assert(type(opts) == 'table', 'Options must be a table')
    if not SETTINGS then
      SetDefaults()
    end
    for k, v in pairs(opts) do
      if k == 'autocomplete' then
        if v == 'triggers' then
          -- special case: { autocomplete = 'triggers' }
          v = {
            enabled = true,
            prefix = false,
          }
        elseif type(v) == 'boolean' then
          -- special case: { autocomplete = boolean }
          v = { enabled = v }
        end
        tbl.merge(SETTINGS.autocomplete, v)
      elseif k == 'info' or k == 'signature' then
        if v == true then
          v = tbl.copy(SETTINGS[k])
          tbl.merge(SETTINGS[k], v)
        elseif v == false then
          SETTINGS[k] = v
        elseif type(v) == 'table' then
          tbl.merge(SETTINGS[k], v)
        end
      elseif SETTINGS[k] then
        SETTINGS[k] = v
      end
    end
  end,

  settings = setmetatable({}, {

    __index = function(_, k)
      if PRIVATE[k] ~= nil then
        return PRIVATE[k]
      else
        return SETTINGS[k]
      end
    end,

    __newindex = function(_, k, v)
      assert(SETTINGS[k] ~= nil or PRIVATE[k] ~= nil, 'Invalid setting')
      if SETTINGS[k] then
        SETTINGS[k] = v
      else
        PRIVATE[k] = v
      end
    end,
  }),

  SetDefaults = SetDefaults,
  PrintSettings = PrintSettings,
  PrintAutocomplete = PrintAutocomplete,
  MakeChainSettings = MakeChainSettings,
  MakeAutocompleteOpts = MakeAutocompleteOpts,
  DefaultChain = DefaultChain,
}

-- vim: ft=lua et ts=2 sw=2 fdm=marker
