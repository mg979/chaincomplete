local M = {}

local S = require('chaincomplete.settings')
local tbl = require("nvim-lib").tbl
local arr = require("nvim-lib").arr
local Chain = require('chaincomplete.chain')
local Methods = require('chaincomplete.methods')
local Auto = require('chaincomplete.auto')

-------------------------------------------------------------------------------
-- :ChainComplete command
-------------------------------------------------------------------------------

--- Verify that methods in the given chain are valid.
--- @param s string: the :ChainComplete input or arguments
--- @return table|nil: chain object
local function verify_chain(s)
  local methods, chain = {}, Chain.GetChain()
  if s:find('^[1-9%+%-%^]%w') then
    local pos, m = s:sub(1, 1), s:sub(2)
    if Methods[m] then
      if pos == '^' then
        table.insert(arr.remove(chain, m), 1, m)
      elseif pos == '+' then
        table.insert(arr.remove(chain, m), m)
      elseif pos == '-' then
        arr.remove(chain, m)
      else
        local i = math.min(#chain, pos)
        table.insert(arr.remove(chain, m), i, m)
      end
    end
  else
    for v in s:gmatch('([a-z%-]+),?') do
      if Methods[v] then
        table.insert(methods, v)
      end
    end
  end
  return #methods > 0 and Chain.NewChain(methods) or chain
end

--- Get chain from command line input().
--- @return table|nil: chain object
local function from_input()
  local input = vim.fn.input('Enter a new chain: ', tostring(Chain.GetChain()))
  if input == '' then
    return nil
  end
  return verify_chain(input)
end

-------------------------------------------------------------------------------
-- :ChainComplete
-------------------------------------------------------------------------------

-- ":ChainComplete" command
--- Set/reset/show the chain for current buffer.
--- @param args string: methods, separated by space
--- @param input boolean: get chain from input
--- @param echo boolean: print current chain to command line
function M.ChainComplete(args, input, echo)
  local chain

  if args == 'settings' then
    S.PrintSettings()
    return

  elseif args == 'reset' then
    chain = Chain.NewChain()

  elseif input then
    chain = from_input()

  elseif args ~= '' then
    chain = verify_chain(args)
  end

  if chain then
    Chain.SetChain(chain)
  end

  if echo then
    vim.cmd('redraw')
    print('current chain: ' .. tostring(Chain.GetChain()))
  end
end

-------------------------------------------------------------------------------
-- :AutoComplete
-------------------------------------------------------------------------------

local function parse_triggers(punct)
  if not punct then
    return false
  end
  local triggers = {}
  local i = 0
  for chars in punct:gmatch('%p+') do
    i = i + 1
    triggers[i] = chars
  end
  if i == 0 then
    return nil
  end
  return triggers
end

-------------------------------------------------------------------------------
--- ":AutoComplete" command.
--- Enable/disable autocompletion for current buffer/filetype.
---@param ftlocal bool
---@param args string
---@param verbose bool
function M.AutoComplete(ftlocal, args, mods)
  vim.cmd.redraw()
  args = ' ' .. args .. ' '
  local ft = ftlocal and vim.o.filetype
  local verbose = mods:find('verbose')

  -- the `ac` table will be merged with the current settings
  local ac = {
    prefix = tonumber(args:match(' %d+ ')) or false,
    triggers = parse_triggers(args:match(' %p+ ')),
  }

  if args:find(' toggle ') then -- if toggle {{{1
    ac.enabled = not S.settings.autocomplete.enabled[ft or '*']

  elseif args:find(' on ') then -- else if on {{{1
    ac.enabled = true
    ac.prefix = ac.prefix or 3

  elseif args:find(' off ') then -- else if off {{{1
    ac.enabled = false

  elseif args:find(' triggers ') then -- else if triggers {{{1
    ac.enabled = true
    ac.triggers = ac.triggers or true

  elseif args:find(' notriggers ') then -- else if notriggers {{{1
    ac.enabled = true
    ac.triggers = false

  elseif ac.triggers or ac.prefix then -- else if args {{{1
    ac.enabled = true

  elseif verbose then -- else print current settings {{{1
    S.PrintAutocomplete()
    return
  else
    print('AutoComplete: not verbose? no arguments?')
    return
  end -- }}}

  -- turn the table into a format that can be merged
  tbl.map(ac, function(_, v)
    return { [ft or '*'] = v }
  end)

  -- update settings
  S.settings.autocomplete = S.MakeAutocompleteOpts(ac)

  -- apply to all chains
  Chain.UpdateChains()

  if verbose then
    S.PrintAutocomplete()
  end
end

return M
-- vim: ft=lua et ts=2 sw=2 fdm=marker
