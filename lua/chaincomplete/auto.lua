-- local variables {{{1
local api, nvim, tbl = require("nvim-lib")()
local U = require('chaincomplete.util')
local GetChain = require('chaincomplete.chain').GetChain

local pumvisible = vim.fn.pumvisible
local col = vim.fn.col
local vmatch = vim.fn.match
--}}}

local auto = {}

local timer
local plug = nvim.keycodes["<Plug>(AutoComplete)"]

local get_prefix = U.get_prefix

--- Whether characters before cursor can trigger autocompletion, when enabled.
--- Here, lsp triggers will only be checked if there are no trigger patterns
--- defined for the current filetype.
--- @return boolean
local function can_autocomplete()
  local chain = GetChain()

  -- not all methods are allowed to use triggers
  chain.cur_trigger = false

  local pre = chain.prefix
  local tt = chain.trigpats
  local coln = col('.')
  if coln < (pre or 3) then
    return false
  end

  local chars = get_prefix(coln, pre or 3)
  if not chars then
    return false
  end

  if pre and vmatch(chars, '^\\k\\+$') ~= -1 then
    return true
  end

  local symbol = chars:match('[.$:<>"*/]$')
  if not symbol then
    return false
  end

  -- chain.triggers can be `true`, without defining the trigger themselves
  -- use lsp triggers if possible
  if not tt and chain.triggers and chain.lsp_triggers then
    if tbl.contains(chain.lsp_triggers, symbol) then
      chain.cur_trigger = symbol
      return true
    end
  elseif tt then
    for _, t in ipairs(tt) do -- trigger characters
      if chars:match(t .. '$') then
        chain.cur_trigger = symbol
        return true
      end
    end
  end
  return false
end

-------------------------------------------------------------------------------
-- Autocompletion timer
-------------------------------------------------------------------------------

--- Called on InsertCharPre, to ensure 'noselect' flag is enabled.
--- Will also reset the 'halted' flag to resume autocompletion.
function auto.check()
  U.noselect(true)
  auto.halted = false
end

--- Called on text changes in insert mode.
function auto.start()
  GetChain():reset()
  auto.stop()
  if not auto.halted and pumvisible() == 0 then
    timer = vim.loop.new_timer()
    timer:start(100, 0, vim.schedule_wrap(auto.complete))
  end
  -- this seems to be needed to retrigger the popup consistently on <BS>
  if GetChain().retrigger_on_BS then
    auto.halted = false
  end
end

--- Stop timer if currently running.
function auto.stop()
  if timer then
    timer:close()
    timer = nil
  end
end

--- Callback of auto.start, to try autocompletion.
function auto.complete()
  auto.stop()
  if pumvisible() == 0 and can_autocomplete() then
    api.feedkeys(plug, "m", false)
  end
end

--- Called on CompleteDone, to prevent immediate retriggering
function auto.halt()
  auto.stop()
  auto.halted = true
end

local ID -- augroup id

function auto.autocmds(chain)
  if not ID and chain.autocomplete then
    U.noselect(true)
    U.menuone(true)
    ID = nvim.augroup('chaincomplete-auto')({
      { 'InsertCharPre', callback = auto.check },
      { 'TextChangedP', callback = auto.check },
      { 'TextChangedI', callback = auto.start },
      { 'InsertLeave', callback = auto.stop },
      { 'CompleteDone', callback = auto.halt },
    })
  elseif ID and not chain.autocomplete then
    U.noselect(false)
    U.menuone(false)
    api.del_augroup_by_id(ID)
    ID = nil
  end
end

return auto
