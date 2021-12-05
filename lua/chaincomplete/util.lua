local col = vim.fn.col
local line = vim.fn.line
local getlines = vim.api.nvim_buf_get_lines
local sl = vim.fn.has('win32') == 1 and '\\' or '/'

local util = {}

util.feedkeys = vim.api.nvim_feedkeys

function util.keys(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function prefix(length)
  local l, c = line('.'), col('.')
  return c > length - 1 and getlines(0, l - 1, l, true)[1]:sub(c - length, c) or ''
end

function util.can_autocomplete()
  local c = prefix(3)
  return c:match("^%w+$") or c:match("%.$") or c:match("->$")
end

function util.wordchar_before()
  return prefix(1):match("%w")
end

function util.filechar_before()
  local c = prefix(1)
  return c == sl or c:match("%w") or c:match("%p")
end

function util.dot_before()
  return prefix(1) == '.'
end

function util.arrow_before()
  return prefix(2) == '->'
end

----
-- util.default_chain
-- @return: the chain, will use lsp if there are attached clients
----
function util.default_chain()
  if next(vim.lsp.buf_get_clients()) then
    return { 'file', 'lsp', 'user', 'c-n' }
  else
    return { 'file', 'omni', 'user', 'c-n' }
  end
end

return util
