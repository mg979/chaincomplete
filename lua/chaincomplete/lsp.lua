local bufnr = vim.fn.bufnr
local getline = vim.fn.getline
local api = require'chaincomplete.api'

local lsp = {}

lsp.clients = {}

--- Get valid client attached to current buffer.
--- @return table client
function lsp.get_buf_client()
  local client = lsp.clients[bufnr()]
  if client and not client.is_stopped() then
    return client
  end
  for _, c in pairs(vim.lsp.buf_get_clients()) do
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
