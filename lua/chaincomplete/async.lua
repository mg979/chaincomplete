-- local variables {{{1
local util = require'chaincomplete.util'
local resume = util.keys('<Plug>(ChainResume)')
local mode = vim.fn.mode
local pumvisible = vim.fn.pumvisible
local wrap = vim.schedule_wrap
local new_timer = vim.loop.new_timer
local chaincomplete
--}}}

local async = {}

function async.init(cc) -- {{{1
  chaincomplete = cc
  return async
end

function async.start(m, isLast) -- {{{1
  m.items = nil -- clear previous items if any
  if m.handler then m.handler() end
  m.time = m.time or 50
  m.timeout = m.timeout or 300
  async.m = m
  async.canAdvance = not isLast
  async.current = 0
  async.timer = new_timer()
  async.timer:start(m.timeout, m.time, wrap(async.callback))
  vim.cmd([[
    au InsertLeave,BufLeave,InsertCharPre <buffer> call v:lua.chaincomplete.async.stop()
  ]])
end

function async.stop() -- {{{1
  if async.timer then
    async.timer:close()
    async.timer = nil
  end
end

function async.callback() -- {{{1
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

function async.finish() -- {{{1
  if pumvisible() == 0 and async.canAdvance then
    util.feedkeys(resume, 'm', false)
  end
end

-- }}}

return async
