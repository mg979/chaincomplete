-- Much code from mini.completion.
-- https://github.com/echasnovski/mini.completion

local fn = vim.fn
local api = require("nvim-lib").api
local arr = require("nvim-lib").arr
local W = require('chaincomplete.info.window')

local M = {}

-------------------------------------------------------------------------------

--- Create or reuse buffer for floating window.
--- @param cache table: the kind of window
--- @return number: buffer number
function M.make_buf(cache)
  if not cache.bufnr or not api.buf_is_valid(cache.bufnr) then
    cache.bufnr = api.create_buf(false, true)
  end
  return cache.bufnr
end

function M.close_action_window(cache, keep_timer, keep_win)
  if not keep_timer then
    cache.timer:stop()
  end

  if not keep_win then
    if cache.winnr then
      W.close(cache.winnr)
    end
    cache.winnr = nil
  end

  -- For some reason 'buftype' might be reset. Ensure that buffer is scratch.
  if cache.bufnr then
    fn.setbufvar(cache.bufnr, '&buftype', 'nofile')
  end
end

function M.cancel_lsp(caches)
  for _, c in pairs(caches) do
    if c.lsp.status == 'sent' or c.lsp.status == 'received' then
      if c.lsp.cancel_fun then
        c.lsp.cancel_fun()
      end
      c.lsp.status = 'canceled'
    end
  end
end

function M.is_lsp_current(cache, id)
  return cache.lsp.id == id and cache.lsp.status == 'sent'
end

function M.is_whitespace(s)
  if type(s) == 'string' then
    return s:find('^%s*$')
  end
  if type(s) == 'table' then
    for _, val in pairs(s) do
      if not M.is_whitespace(val) then
        return false
      end
    end
    return true
  end
  return false
end

-- Returns tuple of height and width
M.floating_dimensions = function(lines, max_height, max_width)
  max_height, max_width = math.max(max_height, 1), math.max(max_width, 1)

  -- Simulate how lines will look in window with `wrap` and `linebreak`.
  -- This is not 100% accurate (mostly when multibyte characters are present
  -- manifesting into empty space at bottom), but does the job
  local lines_wrap = {}
  for _, l in pairs(lines) do
    arr.extend(lines_wrap, M.wrap_line(l, max_width))
  end
  -- Height is a number of wrapped lines truncated to maximum height
  local height = math.min(#lines_wrap, max_height)

  -- Width is a maximum width of the first `height` wrapped lines truncated to
  -- maximum width
  local width = 0
  local l_width
  for i, l in ipairs(lines_wrap) do
    -- Use `strdisplaywidth()` to account for 'non-UTF8' characters
    l_width = fn.strdisplaywidth(l)
    if i <= height and width < l_width then width = l_width end
  end
  -- It should already be less that that because of wrapping, so this is "just
  -- in case"
  width = math.min(width, max_width)

  return height, width
end

-- Simulate splitting single line `l` like how it would look inside window with
-- `wrap` and `linebreak` set to `true`
M.wrap_line = function(l, width)
  local res = {}

  local success, width_id = true, nil
  -- Use `strdisplaywidth()` to account for multibyte characters
  while success and fn.strdisplaywidth(l) > width do
    -- Simulate wrap by looking at breaking character from end of current break
    -- Use `pcall()` to handle complicated multibyte characters (like Chinese)
    -- for which even `strdisplaywidth()` seems to return incorrect values.
    success, width_id = pcall(vim.str_byteindex, l, width)

    if success then
      local break_match = fn.match(l:sub(1, width_id):reverse(), '[- \t.,;:!?]')
      -- If no breaking character found, wrap at whole width
      local break_id = width_id - (break_match < 0 and 0 or break_match)
      table.insert(res, l:sub(1, break_id))
      l = l:sub(break_id + 1)
    end
  end
  table.insert(res, l)

  return res
end

return M
