local util = require'chaincomplete.util'
local resume = util.keys('<Plug>(ChainResume)')
local mode = vim.fn.mode
local pumvisible = vim.fn.pumvisible
local chaincomplete

local async = {}

function async.init(cc)
  chaincomplete = cc
  return async
end

function async.start(m, isLast)
  m.items = nil -- clear previous items if any
  if m.handler then m.handler() end
  m.time = m.time or 50
  m.timeout = m.timeout or 300
  async.m = m
  async.canAdvance = not isLast
  async.current = 0
  async.timer = vim.fn.timer_start(m.time, async.callback)
  vim.cmd([[
    au InsertLeave,BufLeave,InsertCharPre <buffer> call v:lua.chaincomplete.async.stop()
  ]])
end

function async.stop()
  if async.timer then
    vim.fn.timer_stop(async.timer)
    async.timer = nil
  end
end

function async.callback()
  if mode():match('[iR]') or pumvisible() == 1 then
    return async.stop()
  end

  async.current = async.current + ( async.m.time or 50 )
  if async.current >= ( async.m.timeout or 300 ) then
    return async.finish()
  end

  if async.m.items then
    chaincomplete.invoke(async.m)
  else
    async.timer = vim.fn.timer_start(async.m.time, async.callback)
  end
end

function async.finish()
  if pumvisible() == 0 and async.canAdvance then
    util.feedkeys(resume, 'm', false)
  end
end

return async
