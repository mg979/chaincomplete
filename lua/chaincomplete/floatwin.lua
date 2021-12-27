local api = require'chaincomplete.api'

local win = {}

local close_events = { "CompleteDone", "InsertLeave", "BufLeave" }

--- Get or create floating popup window.
--- @param fopts table: window options
--- @return number: window handle
local function get_winhandle(buf, handle, fopts)
  if not handle or not api.win_is_valid(handle) then
    handle = api.open_win(buf, false, fopts)
    api.win_set_option(handle, 'wrap', true)
    api.close_on_events(close_events, handle)
  end
  api.win_set_config(handle, fopts)
  return handle
end

--- Open a floating window with documentation, or update previous window.
--- @return number: window handle
function win.open(buf, oldwin, opts)
  local pum = api.pum_getpos()
  if not pum.size and oldwin then
    return win.close(oldwin)
  end
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
