local settings = require'chaincomplete.settings'
local intern = require'chaincomplete.intern'
local api = require'chaincomplete.api'
local col = vim.fn.col
local getline = vim.fn.getline
local sl = vim.fn.has('win32') == 1 and '\\' or '/'

local util = {}

--- Translate vim keys notations in a terminal sequence.
--- @param keys string
--- @return string
function util.keys(keys)
  return api.replace_termcodes(keys, true, false, true)
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
  local ac = intern.autocomplete
  local tt = intern.trigpats
  local coln = col('.')
  if coln < (ac.prefix or 3) then
    return false
  end
  local chars = prefix(ac.prefix or 3)
  if ac.prefix then
    if chars:match("^[%w_]+$") then -- keyword characters
      return true
    end
  end
  for _, t in ipairs(tt) do -- trigger characters
    if chars:match(t .. '$') then
      return true
    end
  end
  return false
end

--- If cursor is preceded by trigger characters.
--- @return boolean
function util.trigger_before()
  local tt = intern.trigpats
  local chars = prefix(3)
  for _, t in ipairs(tt) do
    if chars:match(t .. '$') then
      return true
    end
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
  return c == sl or c:match("[%-%~%._%w]")
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

--- Character to the left of the cursor.
--- @return string
function util.get_left_char()
  local line = api.current_line()
  local coln = api.get_cursor(0)[2]

  return string.sub(line, coln, coln)
end

return util

--- vim: ft=lua et ts=2 sw=2 fdm=expr
