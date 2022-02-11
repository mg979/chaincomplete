local bufnr = vim.fn.bufnr
local pumvisible = vim.fn.pumvisible
local util = require'chaincomplete.util'
local methods = require'chaincomplete.methods'
local intern = require'chaincomplete.intern'
local settings = require'chaincomplete.settings'

local cp = util.keys('<C-p>')
local cn = util.keys('<C-n>')
local ce = util.keys('<C-e>')
local tab = util.keys('<Tab>')
local eq = util.keys('<C-r>')
local cr = util.keys('<Cr>')
local cg = util.keys('<C-g><C-g>')
local cgq = '\\<C-g>\\<C-g>'

local reset_if_not_pumvisible = eq .. '=pumvisible() ? "" : "' .. cgq .. '"' .. cr

--------------------------------------------------------------------------------

-- sequences of keys to feed for different types of methods
local vsq = eq .. '=pumvisible() ? "" : v:lua.chaincomplete.keys_complete("%s", "%s")' .. cr
local hsq = eq .. '=pumvisible() ? "" : v:lua.chaincomplete.handler_complete("%s", "%s")' .. cr
local asq = eq .. '=pumvisible() ? "" : v:lua.chaincomplete.async_complete("%s", "%s")' .. cr

local function verify_seq(i, k)  return string.format(vsq, i, k) end
local function async_seq(i, m)   return string.format(asq, i, m) end
local function handler_seq(i, m) return string.format(hsq, i, m) end

-------------------------------------------------------------------------------

local M = {}

-- table with buffers and their active chain
M.buffers = {}

-- autocompletion and async handlers
M.auto = require'chaincomplete.auto'
M.async = require'chaincomplete.async'
M.mini = require'chaincomplete.mini'

M.mini.setup()

local chain     -- current chain
local index = 1 -- current position in the chain

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
  chain = get_chain()
  if pumvisible() == 1 then
    return methods[chain[index]].invert and cp or cn
  end
  if not advancing then
    index = 1
  end
  local ret = ''
  for i = index, #chain do
    local method = chain[i]
    local m = methods[method]
    check_funcs(m)
    if m.can_try() then
      if m.async then
        return ret .. async_seq(i, method)
      elseif m.handler then
        ret = ret .. handler_seq(i, method)
      else
        ret = ret .. verify_seq(i, m.keys)
      end
    end
  end
  if ret == '' then
    return advancing and '' or tab
  else
    return ret .. reset_if_not_pumvisible
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
  index = index % #chain + 1
  return ce .. eq .. '=v:lua.chaincomplete.complete(1)' .. cr
end

-------------------------------------------------------------------------------
--- Returns a key sequence to resume completion, unless the chain has reached
--- its last method.
--- @return string: keys sequence or empty string
---
function M.resume()
  index = index % #chain + 1
  return index > 1 and M.complete(true) or ''
end

-------------------------------------------------------------------------------
--- Store the index in the chain of the next key sequence, then return the
--- method keys sequence. Used by vim ins-completion methods.
--- @param i string: the next method name
--- @return string: reset sequence, then method keys
---
function M.keys_complete(i, keys)
  index = tonumber(i)
  return cg .. keys
end

-------------------------------------------------------------------------------
--- When a method has a special handler based on complete(), this function is
--- called and will on its turn call the method handler.
---
--- Note: this kind of completion is not async. It is for the cases when
--- complete() is used in a blocking manner.
---
--- @param method string: the method name
--- @return string: keys sequence or empty string
---
function M.handler_complete(i, method)
  index = tonumber(i)
  local m = methods[method]
  return cg .. ( m.handler() or m.keys or '' )
end

-------------------------------------------------------------------------------
--- Called by async methods.
--- @param method string: the method name
--- @return string: keys sequence or empty string
---
function M.async_complete(i, method)
  index = tonumber(i)
  local isLast = index == #chain
  M.async.start(methods[method], isLast)
  return cg .. ( methods[method].keys or '' )
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

return M
