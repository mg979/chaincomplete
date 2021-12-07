local lsp = require'chaincomplete.lsp'
local util = require 'chaincomplete.util'
local lsputil = vim.lsp.util
local bufnr = vim.fn.bufnr

local M = {}

local function is_lsp_item(ud)
  return type(ud) == 'table' and ud.nvim and ud.nvim.lsp
end

local function get_position(item)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = vim.str_utfindex(util.getline(row), col)
  return { line = row - 1, character = col - string.len(item.word) }
end

local function split_to_lines(s)
  local lines = {}
  for line in s:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  return lines
end

local function get_winpos()
  -- TODO: not working if window must be shown on the left of popup menu
  local position = vim.fn.pum_getpos()
  local x = position.width + (position.scrollbar and 1 or 0) -  M.item.word:len()
  local y = position.row - 1
  return x, y
end

local function prepare_popup(_, result)
  if not result or not result.contents then
    vim.defer_fn(M.close, 100)
    return
  end
  local lines = split_to_lines(result.contents.value)
  if vim.tbl_isempty(lines) then
    return
  end

  local x, y = get_winpos()
  local ft = result.contents.kind or 'text'
  local opts = {
    border = 'single',
    relative = 'win',
    offset_x = x,
    row = y,
    close_events = { "CompleteDone", "CompleteChanged", "InsertLeave", "BufLeave" },
  }
  M.bufnr, M.winnr = lsputil.open_floating_preview(lines, ft, opts)
end

function M.close()
  if M.winnr ~= nil and vim.api.nvim_win_is_valid(M.winnr) then
    vim.api.nvim_win_close(M.winnr, true)
    M.winnr = nil
  end
end

function M.open(item)
  if not item.user_data then
    vim.defer_fn(M.close, 100)
    return
  end
  M.item = item
  if lsp.has_hover() and is_lsp_item(item.user_data) then
    local params = {
      textDocument = lsputil.make_text_document_params(),
      position = get_position(item),
    }
    vim.lsp.buf_request(bufnr(), 'textDocument/hover', params, prepare_popup)
  end
end

return M
