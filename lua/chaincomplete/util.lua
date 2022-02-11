local settings = require'chaincomplete.settings'
local col = vim.fn.col
local getline = vim.fn.getline
local sl = vim.fn.has('win32') == 1 and '\\' or '/'

local util = {}

--- Translate vim keys notations in a terminal sequence.
--- @param keys string
--- @return string
function util.keys(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

--- Get N characters before cursor.
--- @param length number: the number of characters
--- @return string
local function prefix(length)
  local c = col('.')
  return c > length and getline('.'):sub(c - length, c - 1) or ''
end

--- If characters before cursor can trigger autocompletion, when enabled.
--- @return boolean
function util.can_autocomplete()
  local ac = settings.autocomplete
  local c
  local coln = col('.')
  local len = coln == 3 and 2 or 3
  if coln > 2 then
    if next(ac.triggers) then
      c = prefix(len)
      for _, t in ipairs(ac.triggers) do
        if c:match(t .. '$') then
          return true
        end
      end
    end
  end
  if ac.prefix then
    if not c or ac.prefix ~= len then
      c = prefix(ac.prefix)
    end
    return c:match("^[%w_]+$")
  end
  return false
end

--- If character before cursor is a 'word' character.
--- @return boolean
function util.wordchar_before()
  return prefix(1):match("[%w_]")
end

--- If character before cursor is a 'word' character or punctuation.
--- @return boolean
function util.filechar_before()
  local c = prefix(1)
  return c == sl or c:match("[%-%~_%w]")
end

--- If character before cursor is a dot.
--- @return boolean
function util.dot_before()
  return prefix(1) == '.'
end

--- If characters before cursor are an arrow operator.
--- @return boolean
function util.arrow_before()
  return prefix(2) == '->'
end

--- Default chain for current buffer.
--- @return table chain
function util.default_chain()
  if vim.o.omnifunc == 'v:lua.vim.lsp.omnifunc' then
    return settings.chain_lsp
  end
  for _, client in pairs(vim.lsp.buf_get_clients()) do
    if client.resolved_capabilities.completion then
      return settings.chain_lsp
    end
  end
  return settings.chain_nolsp
end

return util

--- vim: ft=lua et ts=2 sw=2 fdm=expr
