local lsp = require'chaincomplete.lsp'
local api = require'chaincomplete.api'
local win = require'chaincomplete.floatwin'
local settings = require'chaincomplete.settings'
local bufnr = vim.fn.bufnr
local extend = vim.list_extend
local split = vim.split

local M = {}

--- Open the floating popup window, if there's some valid result to show.
--- @param result table: passed by buf_request
local function prepare_popup(_, result)
  if not result or not result.contents then
    return win.close()
  end
  if not result.contents.value or result.contents.value == '' then
    return
  end
  win.open(result.contents.value, result.contents.kind or '')
end

--- Main docpopup module function.
--- Popup contents can be either provided by lsp (item.user_data.nvim.lsp), or
--- contained in item.info.
--- @param item table: item that is being completed
function M.open(item)
  if not settings.docpopup then
    return
  elseif not item.user_data and not item.info then
    return win.close()
  end
  if lsp.has_hover() and lsp.is_lsp_item(item.user_data) then
    local params = {
      textDocument = api.make_text_document_params(),
      position = lsp.get_position(item),
    }
    vim.lsp.buf_request(bufnr(), 'textDocument/hover', params, prepare_popup)
  elseif item.info and item.info:match('%w') then
    return vim.defer_fn(function()
      -- from https://github.com/echasnovski/mini.nvim
      local lines = { '<text>' }
      extend(lines, split(item.info, '\n', false))
      table.insert(lines, '</text>')
      prepare_popup(nil, { contents = { value = lines } })
    end, 20)
  else
    return win.close()
  end
end

return M

-- vim: ft=lua et ts=2 sw=2 fdm=expr
