local bufnr = vim.fn.bufnr
local getline = vim.fn.getline
local api = require'chaincomplete.api'
local tbl_contains = vim.tbl_contains
local get_clients = vim.lsp.buf_get_clients

local lsp = {}

lsp.clients = {}

--- Get valid client attached to current buffer.
--- @return table client
function lsp.get_buf_client()
  local client = lsp.clients[bufnr()]
  if client and not client.is_stopped() then
    return client
  end
  for _, c in pairs(get_clients()) do
    if not c.is_stopped() and c.resolved_capabilities.completion then
      lsp.clients[bufnr()] = c
      break
    end
  end
  return lsp.clients[bufnr()]
end

--- If the completed item has lsp informations.
--- @param ud table: item.user_data
--- @return boolean
function lsp.is_lsp_item(ud)
  return ud and type(ud) == 'table' and ud.nvim and ud.nvim.lsp
end

--- If it's a valid lsp completion trigger character.
--- @param char string
--- @return boolean
function lsp.is_completion_trigger(char)
  local triggers
  for _, client in pairs(get_clients()) do
    triggers = ((client.server_capabilities or {}).completionProvider or {}).triggerCharacters
    if triggers and tbl_contains(triggers, char) then
      return true
    end
  end
  return false
end

--- If it's a valid lsp signature trigger character.
--- @param char string
--- @return boolean
function lsp.is_signature_trigger(char)
  if char:match('[(),]') then
    return true
  elseif char:match('%w') then
    return false
  end
  local triggers
  for _, client in pairs(get_clients()) do
    triggers = ((client.server_capabilities or {}).signatureHelpProvider or {}).triggerCharacters
    if triggers and tbl_contains(triggers, char) then
      return true
    end
  end
  return false
end

--- If the currently attached client suppors hover documentation.
--- @return boolean
function lsp.has_hover()
  local client = lsp.clients[bufnr()]
  return client and client.resolved_capabilities.hover
end

--- Position table, as needed by vim.lsp.buf_request.
--- @param item table: item that is being completed
--- @return table position
function lsp.get_position(item)
  local row, col = unpack(api.get_cursor(0))
  col = vim.str_utfindex(getline(row), col)
  return { line = row - 1, character = col - string.len(item.word) }
end

return lsp

-- vim: ft=lua et ts=2 sw=2 fdm=expr
