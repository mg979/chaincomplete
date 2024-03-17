local Settings = require('chaincomplete.settings').settings

local api = require("nvim-lib").api
local getline, mode, vmatch = vim.fn.getline, vim.fn.mode, vim.fn.match
local trim_empty = vim.lsp.util.trim_empty_lines
local convert_to_markdown = vim.lsp.util.convert_input_to_markdown_lines

local U = {}

U.make_position_params = vim.lsp.util.make_position_params
U.stylize_markdown = vim.lsp.util.stylize_markdown

--- Get N characters before cursor.
--- @param length number: the number of characters
--- @return string|nil
function U.get_prefix(c, length)
  return c > length and getline('.'):sub(c - length, c - 1)
end

--- Set method omnifunc/completefunc if necessary.
--- @param method table
function U.check_funcs(method)
  if method.omnifunc and vim.o.omnifunc ~= method.omnifunc then
    vim.o.omnifunc = method.omnifunc
  elseif method.completefunc and vim.o.completefunc ~= method.completefunc then
    vim.o.completefunc = method.completefunc
  end
end

--- Ensure the first item is selected during manual completion.
--- `noselect` must be true if autocompletion is enabled.
function U.noselect(enable)
  if enable and not Settings.noselect then
    Settings.noselect = true
    vim.opt.completeopt:append('noselect')
  elseif not enable and Settings.noselect then
    Settings.noselect = false
    vim.opt.completeopt:remove('noselect')
  end
end

--- Set the completeopt `menuone` flag.
--- `menuone` must be true if autocompletion is enabled.
function U.menuone(enable)
  if enable and not Settings.menuone then
    Settings.menuone = true
    vim.opt.completeopt:append('menuone')
  elseif not enable and Settings.menuone then
    Settings.menuone = false
    vim.opt.completeopt:remove('menuone')
  end
end

--- Remove noise from markdown lines.
---@param lines table
---@return table
function U.sanitize_markdown(lines)
  lines = trim_empty(convert_to_markdown(lines))
  for n in ipairs(lines) do
    lines[n] = lines[n]:gsub("\\(.)", "%1") -- spurious backslashes
    lines[n] = lines[n]:gsub("{{{%d", "") -- fold markers
    lines[n] = lines[n]:gsub("%[(.-)%]%(.-%)", "%1") -- links
  end
  return lines
end

function U.is_insert_mode()
  return mode():match('[iR]')
end

function U.convert_to_markdown(lines)
  return trim_empty(convert_to_markdown(lines))
end

--- Compute start position of latest keyword.
function U.get_completion_start()
  local col = api.win_get_cursor(0)[2]
  local line_to_cursor = api.get_current_line():sub(1, col)
  local pos = vmatch(line_to_cursor, '\\k*$')
  if pos >= 0 then
    return pos, line_to_cursor:sub(pos + 1, col)
  end
end

return U

--- vim: ft=lua et ts=2 sw=2 fdm=expr
