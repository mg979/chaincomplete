local util = require'chaincomplete.util'
local chaincomplete
local auto = {}

function auto.init(cc)
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

local timer
local pumvisible = vim.fn.pumvisible
local has_word_before = require'chaincomplete.util'.has_word_before
local open_popup = util.keys('<Plug>(ChainComplete)')

function auto.start() -- {{{1
  auto.stop()
  if pumvisible() == 1 then
    timer = vim.defer_fn(auto.complete, 100)
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
  if pumvisible() == 0 and has_word_before() then
    util.feedkeys(open_popup, 'm', false)
  end
end

-- }}}

return auto
