-- local variables {{{1
local nvim = require("nvim-lib").nvim
local api = require'chaincomplete.api'
local completeitems = require'chaincomplete.completeitems'
local resume = nvim.keycodes['<Plug>(ChainResume)']
local mode = vim.fn.mode
local pumvisible = vim.fn.pumvisible
--}}}

local async = {}

function async.start(m, isLast)
  -- clear previous items/handled state
  async.items = nil
  async.handled = false
  async.time = m.time or 50
  async.timeout = m.timeout or 300
  async.canAdvance = not isLast
  async.current = 0
  async.canceled = false
  async.cancel = m.cancel
  async.timer = vim.defer_fn(async.callback, async.time)
  if type(m.async) == 'function' then m.async(async) end
  vim.cmd([[
    au InsertLeave,BufLeave,InsertCharPre <buffer> ++once lua Chaincomplete.async.canceled = true
  ]])
end

function async.callback()
  if async.canceled or pumvisible() == 1 or (mode() ~= 'i' and mode() ~= 'R') then
    return
  end

  async.current = async.current + async.time
  if async.current >= async.timeout then
    if async.cancel then
      async.cancel()
    end
    return async.finish()
  end

  if async.handled then
    return async.finish()
  elseif async.items then
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
  -- Defer function for the case that popup isn't visible yet when the async
  -- handler returns
  vim.defer_fn(function()
    if pumvisible() == 0 and async.canAdvance then
      api.feedkeys(resume, 'm', false)
    end
  end, 50)
end

return async
