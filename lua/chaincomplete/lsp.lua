local bufnr = vim.fn.bufnr
local getline = vim.fn.getline
local api = require("nvim-lib").api
local tbl = require("nvim-lib").tbl

local lsp = { clients = {} }

local function get_clients()
  return api.get_active_clients({ bufnr = bufnr() })
end

--- Fields to check for providers, based on nvim version.
function lsp.providers()
  return 'server_capabilities', 'completionProvider', 'hoverProvider', 'signatureHelpProvider'
end

--- If there are valid lsp clients attached to current buffer.
---@return boolean
function lsp.has_client_running()
  for _, c in pairs(get_clients()) do
    if not c.is_stopped() then
      return true
    end
  end
  return false
end

--- Test if an attached client supports the requested capability.
---@param capability string
---@return boolean
function lsp.has_capability(capability)
  for _, c in pairs(get_clients()) do
    if c.server_capabilities[capability] then
      return true
    end
  end
  return false
end

--- Get valid client attached to current buffer.
--- @return table client
function lsp.get_buf_client()
  local client = lsp.clients[bufnr()]
  if client and not client.is_stopped() then
    return client
  end
  for _, c in pairs(get_clients()) do
    if not c.is_stopped() and c.server_capabilities.completionProvider then
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
    if triggers and tbl.contains(triggers, char) then
      return true
    end
  end
  return false
end

--- If the currently attached client suppors hover documentation.
--- @return boolean
function lsp.has_hover()
  local client = lsp.clients[bufnr()]
  return client and client.server_capabilities.hoverProvider
end

--- Position table, as needed by vim.lsp.buf_request.
--- @param item table: item that is being completed
--- @return table position
function lsp.get_position(item)
  local row, col = unpack(api.win_get_cursor(0))
  col = vim.str_utfindex(getline(row), col)
  return { line = row - 1, character = col - string.len(item.word) }
end

return lsp

-- vim: ft=lua et ts=2 sw=2 fdm=expr
