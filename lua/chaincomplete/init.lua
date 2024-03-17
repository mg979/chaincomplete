-------------------------------------------------------------------------------
-- Insert mode chained completion
-------------------------------------------------------------------------------

local fn = vim.fn
local pumvisible = fn.pumvisible
local Keys = require('nvim-lib').nvim.keycodes
local api, nvim = require('nvim-lib')()
local C = require('chaincomplete.chain')
local S = require('chaincomplete.settings')

local Chain -- current chain

local Auto = require('chaincomplete.auto')
local Methods = require('chaincomplete.methods')
local U = require('chaincomplete.util')

local M = {}

_G.Chaincomplete = M

_G.Chaincomplete.omnifunc_sync = require('chaincomplete.omnifunc').omnifunc_sync
_G.Chaincomplete.omnifunc_sync_fuzzy = require('chaincomplete.omnifunc').omnifunc_sync_fuzzy

-- local Empty = Keys.CtrlR .. '=\r'

-------------------------------------------------------------------------------
-- keys
-------------------------------------------------------------------------------

-- TRUE if something has just been completed
local function completed()
  return next(fn.complete_info({ 'items' }).items) ~= nil
end

-- don't leave completion in a lingering stae
local ResetCompletion = Keys.CtrlG .. Keys.CtrlG

local MANUAL = 0
local ADVANCE = 1
local VERIFY = 2
local RESUME = 3

-------------------------------------------------------------------------------
--- Try several completion methods in insert mode.
---
---@param mode number|nil:
---     MANUAL  = 0       (manual completion)
---     ADVANCE = 1       (manually advancing chain)
---     VERIFY  = 2       (verifying results, could advance chain)
---     RESUME  = 3       (resuming after an attempt of async completion)
---     AUTO    = nil     (autocompletion)
function M.Complete(mode)
  -- the `manual` flag is reset in Chain:next()
  -- it is always false during autocompletion
  Chain.manual = Chain.manual or mode == MANUAL or mode == ADVANCE

  if mode == MANUAL and pumvisible() == 0 then
    U.noselect(false)
    U.menuone(false)
    Chain:reset()

  elseif mode == ADVANCE or Chain.autocomplete then
    U.noselect(true)
    U.menuone(true)
  end

  -- print(mode, Chain.index, pumvisible() == 1)
  local ret

  if mode == ADVANCE then
    -- print('advance,', Chain.index, completed())
    ret = (completed() and Keys.CtrlE or '') .. Chain:next()

  elseif pumvisible() == 1 then
    ret = mode == VERIFY and '' or Chain:invert() and Keys.CtrlP or Keys.CtrlN

  elseif mode == VERIFY and completed() then
    -- there was a single item and popup didn't open (no `menuone` in 'cot')
    -- print('completed')
    ret = ''

  elseif mode == VERIFY and Chain:is_last() then
    -- print('is_last')
    ret = ResetCompletion

  else
    -- print('next,', Chain.index)
    ret = Chain:next()
  end
  -- print(ret)
  return ret
end

-------------------------------------------------------------------------------
--- Initialize chain on InsertEnter.
--- Make sure lsp omnifunc is replaced with our own.
--- Check other omnifunc/completefunc values.
function M.Init()
  Chain = C.GetChain()
  -- check autocommands for autocompletion
  Auto.autocmds(Chain)
end

function M.Items()
  return C.GetChain():complete()
end

-- Update chain objects with new lsp informations.
api.create_autocmd('LspAttach', {
  callback = function(ev)
    local s = S.MakeChainSettings(ev.buf)
    C.UpdateChain(ev.buf, {
      lsp = s.lsp,
      lsp_triggers = s.lsp_triggers,
      info = s.info,
    })
  end,
})

nvim.augroup('chaincomplete-info')({
  { 'CompleteChanged', callback = require('chaincomplete.info.popup').ShowInfo },
  { 'CompleteDonePre', callback = require('chaincomplete.info.popup').CloseInfo },
  { 'InsertLeavePre', callback = require('chaincomplete.info.signature').CloseSignature },
  { 'CursorMovedI', callback = require('chaincomplete.info.signature').ShowSignature },
  { 'TextChangedI', callback = require('chaincomplete.info.signature').ShowSignature },
  { 'InsertEnter', callback = require('chaincomplete.info.signature').ShowSignature },
})

return M
