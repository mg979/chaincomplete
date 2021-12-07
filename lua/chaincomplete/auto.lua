-- local variables {{{1
local util = require'chaincomplete.util'
local settings = require'chaincomplete.settings'
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

function auto.enable()
  if settings.autocomplete then
    return
  end
  settings.autocomplete = true
  vim.opt.completeopt:append('noselect')
  vim.cmd( -- enable autocommands {{{1
    [[
  augroup chaincomplete_auto
    au!
    autocmd InsertCharPre * noautocmd call v:lua.chaincomplete.auto.start()
    autocmd InsertLeave   * noautocmd call v:lua.chaincomplete.auto.stop()
  augroup END
  ]]) -- }}}
end

function auto.disable()
  if not settings.autocomplete then
    return
  end
  settings.autocomplete = false
  vim.opt.completeopt:remove('noselect')
  vim.cmd( -- disable autocommands {{{1
    [[
    au! chaincomplete_auto
    aug! chaincomplete_auto
  ]]) -- }}}
end

function auto.toggle()
  if settings.autocomplete then
    auto.disable()
  else
    auto.enable()
  end
end


-------------------------------------------------------------------------------
-- Autocompletion timer
-------------------------------------------------------------------------------

function auto.start()
  auto.stop()
  if pumvisible() == 0 then
    timer = vim.loop.new_timer()
    timer:start(100, 0, wrap(auto.complete))
  end
end

function auto.stop()
  if timer then
    timer:close()
    timer = nil
  end
end

function auto.complete()
  auto.stop()
  if pumvisible() == 0 and can_autocomplete() then
    util.feedkeys(open_popup, 'm', false)
  end
end

return auto
