local api = require'chaincomplete.api'
local intern = require'chaincomplete.intern'
local strwidth = vim.str_utfindex

local win = {}

local close_events = { "CompleteDone", "InsertLeave", "BufLeave" }

--- Default popup options
--- @return table options
local function floatopts()
  return {
    border = intern.border.style,
    relative = 'editor',
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
    wrap_at = 80,
  }
end

--- Get the floating window position.
--- @param lines table
--- @return number row, number column
local function get_winpos(pum, lines, width, height)
  -- extra width/height for borders, if any
  local BCOL, BROW = intern.border.col, intern.border.row
  local all = vim.o.columns - BCOL + 1
  local row = pum.row
  local col = pum.col + pum.width + (pum.scrollbar and 1 or 0)
  local free_right = all - col
  local free_left = pum.col
  if free_right < free_left then
    col = pum.col - width - BCOL
  end
  if col < 0 or col + width > all then
    col = pum.col
    row = pum.row + pum.size
    if row + height > vim.o.lines then
      col = col - 1
      row = pum.row - height - BROW
    end
  end
  return row, col
end

--- Get the width of the floating popup from the longest line of its content.
--- @param lines table
--- @return number
local function get_popup_width(lines)
  local w, max = 0, 80
  for _, l in ipairs(lines) do
    local lw = strwidth(l)
    if lw > max then
      return max
    elseif lw > w then
      w = lw
    end
  end
  return w
end

--- Make options for floating popup and for stylize_markdown.
--- @param pum table: result of vim.fn.pum_getpos
--- @param lines table: text content
--- @return table, table: floating window options, style options
local function info_options(pum, lines)
  local fopts, sopts = floatopts(), styleopts()
  fopts.width = get_popup_width(lines)
  fopts.height = #lines
  fopts.row, fopts.col = get_winpos(pum, lines, fopts.width, fopts.height)
  sopts.max_width = fopts.width
  return fopts, sopts
end

--- Get or create floating popup window.
--- @param fopts table: window options
--- @return number: window handle
local function get_winhandle(buf, handle, fopts)
  if not handle or not api.win_is_valid(handle) then
    handle = api.open_win(buf, false, fopts)
    api.win_set_option(handle, 'wrap', true)
    api.win_set_option(handle, 'linebreak', true)
    api.win_set_option(handle, 'breakindent', false)
    api.close_on_events(close_events, handle)
  end
  api.win_set_config(handle, fopts)
  return handle
end

--- Open a floating window with documentation, or update previous window.
--- @return number: window handle
function win.open_info(buf, lines, oldwin)
  local pum = api.pum_getpos()
  if not pum.size and oldwin then
    return win.close(oldwin)
  end
  local fopts, sopts = info_options(pum, lines)
  api.stylize_markdown(buf, lines, sopts)
  return get_winhandle(buf, oldwin, fopts)
end

function win.open_signature(buf, oldwin, opts)
  return get_winhandle(buf, oldwin, opts)
end

--- Close the window if open (deferred as needed by api).
function win.close(handle)
  vim.defer_fn(function()
    if handle and api.win_is_valid(handle) then
      api.win_close(handle, true)
    end
  end, 20)
end

return win

-- vim: ft=lua et ts=2 sw=2 fdm=expr
