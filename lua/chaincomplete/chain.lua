-------------------------------------------------------------------------------
-- Chain object
-------------------------------------------------------------------------------

local fn = vim.fn
local bufnr = fn.bufnr

local S = require('chaincomplete.settings')
local U = require('chaincomplete.util')
local Methods = require('chaincomplete.methods')
local tbl = require('nvim-lib').tbl
local Keys = require('nvim-lib').nvim.keycodes
local insert = table.insert

-- don't leave completion in a lingering stae
local ResetCompletion = Keys.CtrlG .. Keys.CtrlG

-- will call Complete() to verify results
local Verify = Keys.CtrlR .. '=v:lua.Chaincomplete.Complete(2)\r'

local CompleteItems = Keys.CtrlR .. '=v:lua.Chaincomplete.Items()\r'

-------------------------------------------------------------------------------
-- Chains
-------------------------------------------------------------------------------
-- A chain has its methods names stored in the array part, so that:
--
--   chain[n] -- it's a method name
--
-- The chain also has an hash part, where chain settings are stored.
-- See NewChain() and MakeChainSettings().
--
-------------------------------------------------------------------------------

-- table with buffers and their active chain
local Buffers = {}

-- chain methods
local Chain = {}

--- Metatable for chain object.
local mt = {
  __index = Chain,
  __tostring = function(t)
    return table.concat(t, ', ')
  end,
}

-------------------------------------------------------------------------------
--- Loop through the remaining methods in the chain, see if one can be
--- attempted, in this case return the keys sequence for verification (will call
--- again `Complete()`). Methods can have preconditions to be attempted, or can
--- be skipped while using a trigger that the method doesn't support.
---
---@param advance bool
---@return string
function Chain:next()
  -- If we're here because of a manual completion or chain advancement, we will
  -- keep looping when all remaining methods have failed, at least for the first
  -- round, so that the first valid completion method is tried again.
  local was_manual = self.manual

  local n = #self
  while self.index <= n do
    self.current = self[self.index]
    local m = Methods[self.current]
    -- print(self.index, self[self.index], not m.precond or self[m.precond])

    -- increase index here, before Complete() is called for verification
    self.index = self.index == n and 1 or self.index + 1
    if
      (not m.precond or self[m.precond]) -- method precondition is satisfied
      and (
        not self.cur_trigger -- not using a trigger
        or m.use_triggers == true -- method can use triggers
        or m.use_triggers == self.cur_trigger -- method can use THIS trigger
      )
    then
      U.check_funcs(m)
      return self:items(m) or ResetCompletion .. m.keys .. Verify
    elseif self.index == 1 then -- all methods have been tried unsuccessfully
      break
    end
  end
  -- reset `manual` flag, we repeat the loop only once
  self.manual = false
  return was_manual and self:next() or ''
end

function Chain:items(m)
  if m.items or m.handler then
    return Keys.CtrlR .. '=v:lua.Chaincomplete.Items()\r'
  end
end

function Chain:complete()
  -- TODO: turn this into a completefunc compatible function
  local pos, pre = U.get_completion_start()
  local filtered = {}
  -- smartcase matching: turn 'a' into '[aA]'
  -- local pat = '^' .. vim.pesc(pre):gsub('(%l)', function(v)
  --   return '[' .. v .. v:upper() .. ']'
  -- end)
  -- actually not: with `complete()` it doesn't work well
  -- handlers should create uppercase/lowercase variants as needed
  local pat = '^' .. vim.pesc(pre)
  local m = Methods[self.current]
  for _, item in ipairs(m.items or m.handler(self, pos, pre)) do
    if item:find(pat) then
      insert(filtered, item)
    end
  end
  if next(filtered) then
    fn.complete(pos + 1, filtered)
    return ''
  end
  return self.manual and self:next() or Verify
  -- return Verify
end

-------------------------------------------------------------------------------
--- `true` if the current method starts selecting matches from the bottom.
---@return bool
function Chain:invert()
  return Methods[self[self.index]].invert
end

-------------------------------------------------------------------------------
--- `true` if there are no more methods to attempt after this one.
--- Note: it is `1` because the index has already been reset in Chain:next().
---@return boolean
function Chain:is_last()
  return self.index == 1
end

-------------------------------------------------------------------------------
--- Reset the chain index and flags.
function Chain:reset()
  self.index = 1
  self.manual = false
end

-------------------------------------------------------------------------------
--- Create a new chain, with `methods` or default methods.
---@param methods table
---@return table
local function NewChain(methods)
  local chain = methods or vim.b.completion_chain or S.DefaultChain()
  assert(type(chain) == 'table', 'Completion chain must be an array')
  chain.index = 1
  chain.ft = vim.o.filetype
  tbl.merge(chain, S.MakeChainSettings())
  return setmetatable(chain, mt)
end

-------------------------------------------------------------------------------
--- Get active chain for current buffer, or a default chain.
--- If the filetype changed after the chain was generated, make it anew.
--- @return table: chain
local function GetChain(buf)
  buf = buf or bufnr()
  local chain = Buffers[buf]
  if not chain or vim.o.filetype ~= chain.ft then
    chain = NewChain()
    Buffers[buf] = chain
  end
  return chain
end

-------------------------------------------------------------------------------
--- Set active chain for current buffer.
--- @return table: chain
local function SetChain(chain)
  assert(getmetatable(chain) == mt, 'Table is not a Chain object')
  Buffers[bufnr()] = chain
end

-------------------------------------------------------------------------------
--- Reset chains for filetype, or all chains.
---@param ft string|nil
local function ResetChains(ft)
  for buf, chain in pairs(Buffers) do
    if not ft or chain.ft == ft then
      Buffers[buf] = nil
    end
  end
end

local function UpdateChains()
  for buf, chain in pairs(Buffers) do
    tbl.merge(Buffers[buf], S.MakeChainSettings(buf))
  end
end

local function UpdateChain(buf, opts)
  if not Buffers[buf] then
    return
  end
  tbl.merge(Buffers[buf], opts)
end

return {
  NewChain = NewChain,
  GetChain = GetChain,
  SetChain = SetChain,
  ResetChains = ResetChains,
  UpdateChains = UpdateChains,
  UpdateChain = UpdateChain,
}
