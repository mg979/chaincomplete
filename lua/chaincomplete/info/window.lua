local api, nvim, tbl = require('nvim-lib')()
local fn = vim.fn
local strwidth = vim.str_utfindex
local U = require('chaincomplete.util')

local win = {}
local OPTS, WINHI

--- Default popup options
--- @return table options
local function floatopts()
  return {
    border = OPTS.border,
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
    max_width = OPTS.width,
    max_height = OPTS.height,
    wrap_at = OPTS.width,
  }
end

local function selected_index()
  local n = vim.fn.complete_info({ 'selected' }).selected
  return n >= 0 and n or 0
end

local function darken(color, mod)
  color.ctermbg = color.ctermbg and color.ctermbg - 1
  color.bg = color.bg
    and nvim.highlight.modulate_bg('NormalFloat', mod, mod, mod).int
end

local function get_winhighlight()
  if not WINHI then
    local pmenu = api.get_hl(0, { name = 'Pmenu', link = false })
    local float = api.get_hl(0, { name = 'NormalFloat', link = false })
    local border = tbl.copy(float)
    if
      pmenu.bg == float.bg or (pmenu.ctermbg and pmenu.ctermbg == float.ctermbg)
    then
      darken(border, -10)
      darken(float, -10)
    end
    WINHI = {
      float = float,
      border = border,
    }
    api.set_hl(0, 'CompleteFloat', WINHI.float)
    api.set_hl(0, 'CompleteBorder', WINHI.border)
    api.create_autocmd('Colorscheme', {
      callback = function()
        WINHI = nil
      end,
    })
  end
  return 'NormalFloat:CompleteFloat,FloatBorder:CompleteBorder'
end

--- Get the floating window position.
--- @param lines table
--- @return number row, number column
local function get_winpos(pum, width, height)
  local all = vim.o.columns + 1
  local row = pum.row + selected_index()
  local col = pum.col + pum.width + (pum.scrollbar and 1 or 0)
  local free_right = all - col
  local off = 1 + (OPTS.border ~= 'none' and 2 or 0)
  if free_right < width + off then
    col = pum.col - width - off
  end
  -- if the popup can't be placed on either side, put it above or below
  if col < 0 or col + width > all then
    col = pum.col - 1
    local free_top = pum.row
    local free_bottom = vim.o.lines - pum.row - pum.height + 1
    if free_bottom > free_top then
      -- both pum and info go below cursor
      row = pum.row + pum.height
    else
      -- pum goes below, info goes above, make sure info doesn't go on cursor
      row = pum.row - height - off
      -- if both pum and info go above cursor, no need of extra space between
      local screenline = fn.screenpos(0, fn.line('.'), fn.col('.')).row
      if pum.row < screenline then
        row = row + 1
      end
    end
  end
  return row, col
end

--- Get the width of the floating popup from the longest line of its content.
--- @param lines table
--- @return number
local function get_popup_width(lines)
  local w, max, wrap = 0, OPTS.width, 0
  for _, l in ipairs(lines) do
    local lw = strwidth(l)
    if lw > max then
      wrap = wrap + 1
    elseif lw > w then
      w = lw
    end
  end
  return wrap > 0 and max or w, wrap
end

local function close_on_events(handle)
  api.create_autocmd({ 'CompleteDone', 'InsertLeave', 'BufLeave' }, {
    callback = function()
      if api.win_is_valid(handle) then
        api.win_close(handle, true)
      end
    end,
    once = true,
  })
end

--- Get or create floating popup window.
--- @param fopts table: window options
--- @return number: window handle
local function get_winhandle(buf, handle, fopts, hi)
  if not handle or not api.win_is_valid(handle) then
    handle = api.open_win(buf, false, fopts)
    api.win_set_option(handle, 'wrap', true)
    api.win_set_option(handle, 'linebreak', true)
    api.win_set_option(handle, 'breakindent', false)
    if hi then
      api.win_set_option(handle, 'winhighlight', get_winhighlight())
    end
    close_on_events(handle)
  end
  api.win_set_config(handle, fopts)
  return handle
end

--- Open a floating window with documentation, or update previous window.
--- @return number: window handle
function win.open_info(buf, lines, oldwin, opts)
  local pum = fn.pum_getpos()
  if not pum.size and oldwin then
    return win.close(oldwin)
  end
  OPTS = opts
  local fopts, sopts = floatopts(), styleopts()
  lines = U.stylize_markdown(buf, lines, sopts)
  local wrapped
  fopts.width, wrapped = get_popup_width(lines)
  fopts.height = #lines + wrapped
  fopts.row, fopts.col = get_winpos(pum, fopts.width, fopts.height)
  return get_winhandle(buf, oldwin, fopts, true)
end

function win.open_signature(buf, oldwin, opts)
  OPTS = opts
  return get_winhandle(buf, oldwin, opts, false)
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
