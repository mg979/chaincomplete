local bufnr = vim.fn.bufnr
local pumvisible = vim.fn.pumvisible
local util = require'chaincomplete.util'
local methods = require'chaincomplete.methods'

local cp = util.keys('<C-p>')
local cn = util.keys('<C-n>')
local ce = util.keys('<C-e>')
local tab = util.keys('<Tab>')
local eq = util.keys('<C-r>')
local cr = util.keys('<Cr>')
local cg = '\\<C-g>\\<C-g>'

local reset_if_not_pumvisible = eq .. '=pumvisible() ? "" : "' .. cg .. '"' .. cr

--------------------------------------------------------------------------------

-- sequences of keys to feed for different types of methods
local vsq = eq .. '=pumvisible() ? v:lua.chaincomplete.flag() : v:lua.chaincomplete.set_index("%s") . "' .. cg .. '%s"' .. cr
local hsq = eq .. '=pumvisible() ? v:lua.chaincomplete.flag() : v:lua.chaincomplete.handler_complete("%s")' .. cr
local asq = eq .. '=pumvisible() ? v:lua.chaincomplete.flag() : v:lua.chaincomplete.async_complete("%s")' .. cr

local function verify_seq(m, k) return string.format(vsq, m, k) end
local function async_seq(m)     return string.format(asq, m) end
local function handler_seq(m)   return string.format(hsq, m) end

-------------------------------------------------------------------------------

local M = {}

-- current position in the chain
local index = 1

-- table with buffers and their active chain
M.buffers = {}

-- autocompletion and async handlers
M.auto = require'chaincomplete.auto'
M.async = require'chaincomplete.async'
M.docpopup = require'chaincomplete.docpopup'

local function get_chain(bnr) -- {{{1
  bnr = bnr or bufnr()
  if M.buffers[bnr] then
    return M.buffers[bnr]
  end
  M.buffers[bnr] = vim.b.completion_chain or util.default_chain()
  return M.buffers[bnr]
end

-- }}}

function M.complete(advancing)
  local chain, ret = get_chain(), ''
  if pumvisible() == 1 then
    return chain._invert and cp or cn
  end
  if not advancing then
    index = 1
  end
  for i = index, #chain do
    local method = chain[i]
    local m = methods[method]
    if m.can_try() then
      if m.async then
        return ret .. async_seq(method)
      elseif m.handler then
        ret = ret .. handler_seq(method)
      else
        ret = ret .. verify_seq(method, m.keys)
      end
    end
  end
  if ret == '' then
    return advancing and '' or tab
  else
    return ret .. reset_if_not_pumvisible
  end
end

function M.advance()
  if pumvisible() == 0 then
    return M.complete()
  end
  index = index % #get_chain() + 1
  return ce .. eq .. '=v:lua.chaincomplete.complete(1)' .. cr
end

function M.resume()
  index = index % #get_chain() + 1
  return index > 1 and M.complete(true) or ''
end

function M.flag()
  local chain = get_chain()
  chain._invert = methods[chain[index]].invert
  return ''
end

function M.set_index(m)
  for i, method in ipairs(get_chain()) do
    if method == m then
      index = i
      break
    end
  end
  return ''
end

function M.handler_complete(method)
  M.set_index(method)
  local m = methods[method]
  return m.handler() or m.keys or ''
end

function M.async_complete(method)
  M.set_index(method)
  local isLast = index == #get_chain()
  M.async.start(methods[method], isLast)
  return methods[method].keys or ''
end

-------------------------------------------------------------------------------
-- Set chain for buffer
-------------------------------------------------------------------------------

local function chain_from_input() -- {{{1
  local oldchain = table.concat(get_chain(), ', ')
  local chain = vim.fn.input('Enter a new chain: ', oldchain)
  if chain == '' then
    return nil
  end
  local newchain = {}
  for v in chain:gmatch('[a-z-]+') do
    if methods[v] then
      table.insert(newchain, v)
    end
  end
  return newchain
end

-- }}}

function M.set(bang, args)
  local chain
  if args == 'reset' then
    M.buffers[bufnr()] = util.default_chain()
  elseif bang == 1 then
    chain = chain_from_input()
    if chain then
      M.buffers[bufnr()] = chain
    end
  end
  vim.cmd('redraw')
  print('current chain: ' .. table.concat(get_chain(), ', '))
end

return M
