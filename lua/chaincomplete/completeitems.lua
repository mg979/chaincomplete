local fn = vim.fn
local add = table.insert
local api = require'chaincomplete.api'
local M = {}

function M.invoke(items)
  local word = fn.matchstr(api.current_line():sub(1, fn.col('.')), '\\k*$')
  local valid = {}
  for _, i in ipairs(items) do
    if i:match('^' .. word) then
      add(valid, i)
    end
  end
  fn.complete(fn.col('.') - word:len(), valid)
end

return M
