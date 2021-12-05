-- local variables {{{1
local util = require'chaincomplete.util'
local chaincomplete
local timer
local pumvisible = vim.fn.pumvisible
local wrap = vim.schedule_wrap
local can_autocomplete = require'chaincomplete.util'.can_autocomplete
local open_popup = util.keys('<Plug>(ChainComplete)')
--}}}

-------------------------------------------------------------------------------
-- Initialization, enable, disable, toggle
-------------------------------------------------------------------------------
local auto = {}

function auto.init(cc) -- {{{1
  chaincomplete = cc
  return auto
end

function auto.enable() -- {{{1
  if chaincomplete.autocomplete then
    return
  end
  chaincomplete.autocomplete = true
  vim.opt.completeopt:append('noselect')
  vim.cmd( -- enable autocommands {{{2
    [[
  augroup chaincomplete_auto
    au!
    autocmd InsertCharPre <buffer> noautocmd call v:lua.chaincomplete.auto.start()
    autocmd InsertLeave   <buffer> noautocmd call v:lua.chaincomplete.auto.stop()
  augroup END
  ]]) -- }}}
end

function auto.disable() -- {{{1
  if not chaincomplete.autocomplete then
    return
  end
  chaincomplete.autocomplete = false
  vim.opt.completeopt:remove('noselect')
  vim.cmd( -- disable autocommands {{{2
    [[
    au! chaincomplete_auto
    aug! chaincomplete_auto
  ]]) -- }}}
end

function auto.toggle() -- {{{1
  if chaincomplete.autocomplete then
    auto.disable()
  else
    auto.enable()
  end
end

-- }}}

-------------------------------------------------------------------------------
-- Autocompletion timer
-------------------------------------------------------------------------------

function auto.start() -- {{{1
  auto.stop()
  if pumvisible() == 0 then
    timer = vim.loop.new_timer()
    timer:start(100, 0, wrap(auto.complete))
  end
end

function auto.stop() -- {{{1
  if timer then
    timer:close()
    timer = nil
  end
end

function auto.complete() -- {{{1
  auto.stop()
  if pumvisible() == 0 and can_autocomplete() then
    util.feedkeys(open_popup, 'm', false)
  end
end

-- }}}

return auto
