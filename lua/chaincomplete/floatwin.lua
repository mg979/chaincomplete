local strwidth = vim.str_utfindex
local api = require'chaincomplete.api'

local win = {}

local opts = {
  border = 'single',
  relative = 'win',
  style = 'minimal',
  width = 80,
  height = 80,
}

local winopts = {
  width = 40,
  height = 40,
  max_width = 40,
  max_height = 40,
}

local close_events = { "CompleteDone", "InsertLeave", "BufLeave" }

--- Get the floating window position.
--- @param lines table
--- @return number row, number column
local function get_winpos(lines)
  local pum = api.pum_getpos()
  local row = pum.row - 1
  local col = pum.col + pum.width + (pum.scrollbar and 1 or 0)
  -- local col = pum.width + (pum.scrollbar and 1 or 0)
  return row, col
end

--- Get the width of the floating popup from the longest line of its content.
--- @param lines table
--- @return number
local function get_popup_width(lines)
  local pum = api.pum_getpos()
  local col = pum.col + pum.width + (pum.scrollbar and 1 or 0)
  local max, free = 0, vim.o.columns - col - 2
  for _, l in ipairs(lines) do
    local sw = strwidth(l)
    if sw > free then
      return free
    elseif sw > max then
      max = sw
    end
  end
  return max + 2
end

--- Lines to show in the popup.
--- @param content ...: the text to show in the popup (string or table)
--- @return table: trimmed lines
local function get_lines(content)
  if type(content) == 'table' then
    return api.trim_empty(content)
  end
  return api.trim_empty(api.convert_to_markdown(content))
end

--- Open a floating window with documentation, or update previous window.
--- @param content ...: the text to show in the popup (string or table)
--- @param ft string: the filetype for the popup
--- @return number: window handle
function win.open(content, ft)
  -- local avail = vim.o.columns
  local lines = get_lines(content)
  opts.width = get_popup_width(lines)
  opts.height = #lines
  opts.row, opts.col = get_winpos(lines)
  if not win.buf or not api.buf_is_valid(win.buf) then
    win.buf = api.create_buf(false, true)
  end
  if not win.handle or not api.win_is_valid(win.handle) then
    win.handle = api.open_win(win.buf, false, opts)
  end
  api.buf_set_option(win.buf, 'filetype', ft)
  -- api.buf_set_lines(win.buf, 0, -1, true, lines)
  api.win_set_config(win.handle, opts)
  api.close_on_events(close_events, win.handle)
  api.stylize_markdown(win.buf, lines, winopts)
  return win.handle
end

--- Close the window if open (deferred as needed by api).
function win.close()
  vim.defer_fn(function()
    if win.handle and api.win_is_valid(win.handle) then
      api.win_close(win.handle, true)
      win.handle = nil
    end
  end, 20)
end

return win

-- vim: ft=lua et ts=2 sw=2 fdm=expr
