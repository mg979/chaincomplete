local settings = require'chaincomplete.settings'
local intern = require("chaincomplete.intern")
local api = require("chaincomplete.api")
local lsp = require("chaincomplete.lsp")
local col = vim.fn.col
local getline = vim.fn.getline
local vmatch = vim.fn.match
local sl = vim.fn.has("win32") == 1 and "\\" or "/"

local util = {}

local capabilities = vim.fn.has("nvim-0.8.0") and "server_capabilities" or "resolved_capabilities"

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
  local c = col(".")
  return c > length and getline("."):sub(c - length, c - 1) or ""
end

--- If characters before cursor can trigger autocompletion, when enabled.
--- Here, lsp triggers will only be checked if there are no trigger patterns
--- defined for the current filetype.
--- @return boolean
function util.can_autocomplete()
  local ac = intern.autocomplete
  local tt = intern.trigpats
  local coln = col(".")
  if coln < (ac.prefix or 3) then
    return false
  end
  local chars = prefix(ac.prefix or 3)
  local last = chars:match("%S$")
  if not last then
    return false
  elseif ac.prefix then
    if vmatch(chars, "^\\k\\+$") ~= -1 then -- keyword characters
      return true
    end
  end
  if not tt and ac.triggers and lsp.has_client_running() then
    return lsp.is_completion_trigger(last)
  elseif tt then
    for _, t in ipairs(tt) do -- trigger characters
      if chars:match(t .. "$") then
        return true
      end
    end
  end
  return false
end

--- If cursor is preceded by trigger characters.
--- This is not for autocompletion, rather for when attempting methods, so we
--- always accept lsp triggers when available.
--- @return boolean
function util.trigger_before()
  local tt = intern.trigpats
  local chars = prefix(3)
  if lsp.has_client_running() then
    return lsp.is_completion_trigger(chars:match("%S$"))
  elseif tt then
    for _, t in ipairs(tt) do
      if chars:match(t .. "$") then
        return true
      end
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
  if vim.o.omnifunc == "v:lua.vim.lsp.omnifunc" then
    return settings.chain_lsp
  end
  for _, client in pairs(vim.lsp.buf_get_clients()) do
    if client[capabilities].completion then
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

--- Remove noise from markdown lines.
---@param lines table
---@return table
function util.sanitize_markdown(lines)
  for n, _ in ipairs(lines) do
    lines[n] = lines[n]:gsub("\\(.)", "%1") -- spurious backslashes
    lines[n] = lines[n]:gsub("{{{%d", "") -- fold markers
    lines[n] = lines[n]:gsub("%[(.-)%]%(.-%)", "%1") -- links
  end
  return lines
end

return util

--- vim: ft=lua et ts=2 sw=2 fdm=expr
