-- local variables {{{1
local util = require'chaincomplete.util'
local completeitems = require'chaincomplete.completeitems'
local resume = util.keys('<Plug>(ChainResume)')
local mode = vim.fn.mode
local pumvisible = vim.fn.pumvisible
--}}}

local async = {}

function async.start(m, isLast)
  async.items = nil -- clear previous items if any
  async.time = m.time or 50
  async.timeout = m.timeout or 300
  async.canAdvance = not isLast
  async.current = 0
  async.canceled = false
  async.timer = vim.defer_fn(async.callback, async.time)
  if m.handler then m.handler(async) end
  vim.cmd([[
    au InsertLeave,BufLeave,InsertCharPre <buffer> call v:lua.chaincomplete.async.stop()
  ]])
end

function async.stop()
  async.canceled = true
end

function async.callback()
  if async.canceled or pumvisible() == 1 or (mode() ~= 'i' and mode() ~= 'R') then
    return
  end

  async.current = async.current + async.time
  if async.current >= async.timeout then
    return async.finish()
  end

  if async.items then
    if #async.items == 0 then
      return async.finish()
    end
    completeitems.invoke(async.items)
  else
    -- reinvoke timer because not timed out yet
    async.timer = vim.defer_fn(async.callback, async.time)
  end
end

function async.finish()
  if pumvisible() == 0 and async.canAdvance then
    util.feedkeys(resume, 'm', false)
  end
end

return async
