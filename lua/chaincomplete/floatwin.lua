local strwidth = vim.str_utfindex
local api = require'chaincomplete.api'

local win = {}

--- Default popup options
--- @return table options
local function floatopts()
  return {
    border = 'single',
    relative = 'win',
    style = 'minimal',
  }
end

--- Default popup style options (for stylize_markdown)
--- @return table options
local function styleopts()
  return {
    width = 40,
    height = 40,
    max_width = 40,
    max_height = 40,
  }
end

local close_events = { "CompleteDone", "InsertLeave", "BufLeave" }

--- Get the floating window position.
--- @param lines table
--- @return number row, number column
local function get_winpos(pum, lines)
  local row = pum.row - 1
  local col = pum.col + pum.width + (pum.scrollbar and 1 or 0)
  -- local col = pum.width + (pum.scrollbar and 1 or 0)
  return row, col
end

--- Get the width of the floating popup from the longest line of its content.
--- @param lines table
--- @return number
local function get_popup_width(pum, lines)
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

--- Make options for floating popup and for stylize_markdown.
--- @param pum table: result of vim.fn.pum_getpos
--- @param lines table: text content
--- @return table, table: floating window options, style options
local function make_options(pum, lines)
  local fopts, sopts = floatopts(), styleopts()
  fopts.width = get_popup_width(pum, lines)
  fopts.height = #lines
  fopts.row, fopts.col = get_winpos(pum, lines)
  sopts.max_width = fopts.width
  return fopts, sopts
end

--- Get or create buffer for floating window.
--- @param ft string: buffer filetype
--- @return number buffer
local function get_winbuf(ft)
  if not win.buf or not api.buf_is_valid(win.buf) then
    win.buf = api.create_buf(false, true)
  end
  if api.buf_get_option(win.buf, 'filetype') ~= ft then
    api.buf_set_option(win.buf, 'filetype', ft)
  end
  return win.buf
end

--- Get or create floating popup window.
--- @param fopts table: window options
--- @return number: window handle
local function get_winhandle(fopts)
  if not win.handle or not api.win_is_valid(win.handle) then
    win.handle = api.open_win(win.buf, false, fopts)
    api.win_set_option(win.handle, 'wrap', true)
    api.close_on_events(close_events, win.handle)
  end
  api.win_set_config(win.handle, fopts)
  return win.handle
end

--- Open a floating window with documentation, or update previous window.
--- @param content ...: the text to show in the popup (string or table)
--- @param ft string: the filetype for the popup
--- @return number: window handle
function win.open(content, ft)
  local pum = api.pum_getpos()
  if not pum.size then
    return win.close()
  end
  local lines = get_lines(content)
  local fopts, sopts = make_options(pum, lines)
  win.buf, win.handle = get_winbuf(ft), get_winhandle(fopts)
  api.stylize_markdown(win.buf, lines, sopts)
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
