local api, nvim = require("nvim-lib")()

local bufnr = vim.fn.bufnr
local pumvisible = vim.fn.pumvisible
local util = require('chaincomplete.util')
local methods = require('chaincomplete.methods')
local intern = require('chaincomplete.intern')
local settings = require('chaincomplete.settings')
local completeitems = require('chaincomplete.completeitems').invoke

local CtrlP = nvim.keycodes.CtrlP
local CtrlN = nvim.keycodes.CtrlN
local CtrlE = nvim.keycodes.CtrlE
local Tab = nvim.keycodes.Tab
local CtrlR = nvim.keycodes.CtrlR
local CtrlG = nvim.keycodes['<C-g><C-g>']

local ResetIfNotPumvisible = CtrlR .. '=pumvisible() ? "" : "\\<C-g>\\<C-g>"\r'

--------------------------------------------------------------------------------

-- sequences of keys to feed for different types of methods
local vsq = CtrlR .. '=pumvisible() ? "" : v:lua.Chaincomplete.KeysComplete("%s", "%s")\r'
local hsq = CtrlR .. '=pumvisible() ? "" : v:lua.Chaincomplete.HandlerComplete("%s", "%s")\r'
local asq = CtrlR .. '=pumvisible() ? "" : v:lua.Chaincomplete.AsyncComplete("%s", "%s")\r'

local function Verify(i, k)
  return string.format(vsq, i, k)
end
local function Async(i, m)
  return string.format(asq, i, m)
end
local function Handler(i, m)
  return string.format(hsq, i, m)
end

-------------------------------------------------------------------------------

local M = {}

-- Set global variable to this module
Chaincomplete = M

-- table with buffers and their active chain
M.buffers = {}

-- autocompletion and async handlers
M.auto = require('chaincomplete.auto')
M.async = require('chaincomplete.async')
M.mini = require('chaincomplete.mini')

M.mini.setup()

local CurChain -- current chain
local Index = 1 -- current position in the chain

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------

--- Get active chain for current buffer, or default chain.
--- @param bnr number: buffer number
--- @return table chain
local function get_chain(bnr)
  bnr = bnr or bufnr()
  if M.buffers[bnr] then
    return M.buffers[bnr]
  end
  M.buffers[bnr] = vim.b.completion_chain or util.default_chain()
  return M.buffers[bnr]
end

--- Ensure the first item is selected during manual completion.
--- @param manual boolean
local function ensure_select(manual)
  if manual and intern.noselect then
    intern.noselect = false
    vim.opt.completeopt:remove('noselect')
  end
end

--- Set method omnifunc/completefunc if necessary.
--- @param method table
local function check_funcs(method)
  if method.omnifunc and vim.o.omnifunc ~= method.omnifunc then
    vim.o.omnifunc = method.omnifunc
  elseif method.completefunc and vim.o.completefunc ~= method.completefunc then
    vim.o.completefunc = method.completefunc
  end
end

-------------------------------------------------------------------------------
-- chaincomplete module functions
-------------------------------------------------------------------------------

--- Initialize chain on InsertEnter. Make sure lsp omnifunc is replaced with our
--- own. Check other omnifunc/completefunc values.
function M.init()
  local replace_lsp = vim.o.omnifunc == 'v:lua.vim.lsp.omnifunc'
  CurChain = get_chain()
  for i = 1, #CurChain do
    local method = CurChain[i]
    if replace_lsp and method == 'omni' then
      CurChain[i] = 'lsp'
    end
    check_funcs(methods[method])
  end
end

-------------------------------------------------------------------------------
--- For each method in the active chain, its key sequence is added to the return
--- value if its triggering condition is satisfied. In most cases the condition
--- is a keyword character before the cursor. The key sequence itself includes
--- the keys to try the completion (<C-X>...), followed by a popup check: if the
--- popup is not visible (because the keys couldn't complete anything), the
--- following key sequence will be attempted, otherwise the process stops.
---
--- Some methods may use complete(), and not a <C-X> sequence, so they will use
--- a special handler function. Verification still happens and chain isn't
--- interrupted.
---
--- If the method is async, the verification chain stops and is resumed after the
--- async ruotine has terminated. That is, it is the async routine's
--- responsibility to restart the verification chain, if there are no completion
--- items.
--- @param advancing boolean: invoked when advancing chain
--- @param manual boolean: invoked by manual completion
--- @return string: keys sequence
---
function M.complete(advancing, manual)
  ensure_select(manual)
  if pumvisible() == 1 then
    return methods[CurChain[Index]].invert and CtrlP or CtrlN
  end
  if not advancing then
    Index = 1
  end
  local ret = ''
  for i = Index, #CurChain do
    local method = CurChain[i]
    local m = methods[method]
    if m.can_try() then
      if m.async then
        return ret .. Async(i, method)
      elseif m.items or m.handler then
        ret = ret .. Handler(i, method)
      else
        ret = ret .. Verify(i, m.keys)
      end
    end
  end
  if ret == '' then
    if not settings.autocomplete or not settings.autocomplete.enabled then
      return advancing and '' or Tab
    end
    return manual and Tab or ''
  else
    return ret .. ResetIfNotPumvisible
  end
end

-------------------------------------------------------------------------------
--- Returns a key sequence to cancel current completion and try to complete
--- the next method in the chain, calling ChainComplete() after having advanced
--- the index.
--- @return string: keys sequence
---
function M.advance()
  if pumvisible() == 0 then
    return M.complete()
  end
  Index = index % #CurChain + 1
  return CtrlE .. CtrlR .. '=v:lua.Chaincomplete.complete(1)\r'
end

-------------------------------------------------------------------------------
--- Returns a key sequence to resume completion, unless the chain has reached
--- its last method.
--- @return string: keys sequence or empty string
---
function M.resume()
  Index = Index % #CurChain + 1
  return Index > 1 and M.complete(true) or ''
end

-------------------------------------------------------------------------------
--- Store the index in the chain of the next key sequence, then return the
--- method keys sequence. Used by vim ins-completion methods.
--- @param i number: the method index
--- @return string: reset sequence, then method keys
---
function M.KeysComplete(i, keys)
  Index = tonumber(i)
  return CtrlG .. keys
end

-------------------------------------------------------------------------------
--- When a method has a special handler based on complete(), this function is
--- called and will on its turn call the method handler. Possible variants:
---
--- 1. method has 'handler': m.handler() is called, and it must do everything
---    by itself (make items, call complete())
--- 2. method has 'items', and it's a list: internal handler calls complete()
---    using that list
--- 3. method has 'items', and it's a function: internal handler calls
---    complete() with the result of items(), that must be a list
---
--- Note: this kind of completion is not async. It is for the cases when
--- complete() is used in a blocking manner.
---
--- @param i number: position in the chain
--- @param method string: the method name
--- @return string: keys sequence or empty string
---
function M.HandlerComplete(i, method)
  Index = tonumber(i)
  local m = methods[method]
  if m.handler then
    m.handler()
  else
    completeitems(type(m.items) == 'function' and m.items() or m.items)
  end
  return m.keys and CtrlG .. m.keys or ''
end

-------------------------------------------------------------------------------
--- Called by async methods.
--- @param i number: position in the chain
--- @param method string: the method name
--- @return string: keys sequence or empty string
---
function M.AsyncComplete(i, method)
  Index = tonumber(i)
  local isLast = Index == #CurChain
  M.async.start(methods[method], isLast)
  return CtrlG .. (methods[method].keys or '')
end

-------------------------------------------------------------------------------
-- :ChainComplete command (set chain for buffer)
-------------------------------------------------------------------------------

--- Verify that methods in the given chain are valid.
--- @param s string: the :ChainComplete input
--- @return table: validated chain
local function verify_chain(s)
  local newchain = {}
  for v in s:gmatch('%S+') do
    if methods[v] then
      table.insert(newchain, v)
    end
  end
  return #newchain and newchain or nil
end

--- Get chain from command line input().
--- @return table: the validated chain, or nil
local function chain_from_input()
  local oldchain = table.concat(get_chain(), ' ')
  local input = vim.fn.input('Enter a new chain: ', oldchain)
  if input == '' then
    return nil
  end
  return verify_chain(input)
end

--- Set/reset/show the chain for current buffer.
--- @param args string: methods, separated by space
--- @param input boolean: get chain from input
--- @param echo boolean: print current chain to command line
function M.set_chain(args, input, echo)
  local newchain
  if args == 'settings' then
    return print(vim.inspect(settings))
  elseif args == 'reset' then
    newchain = util.default_chain()
  elseif input then
    newchain = chain_from_input()
  elseif args ~= '' then
    newchain = verify_chain(args)
  end
  if newchain then
    M.buffers[bufnr()] = newchain
  end
  if echo then
    vim.cmd('redraw')
    print('current chain: ' .. table.concat(get_chain(), ', '))
  end
end

-------------------------------------------------------------------------------
-- Registering new methods
-------------------------------------------------------------------------------

--- Register a new completion method, that can be used in a chain.
--- @param name string
--- @param m table
function M.register_method(name, m)
  if not m.can_try or (not m.items and not m.handler and not m.async) then
    print('Failed to register completion method: ' .. name)
    return
  end
  methods[name] = m
end

return M
