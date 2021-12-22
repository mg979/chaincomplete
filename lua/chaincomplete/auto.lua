-- local variables {{{1
local util = require'chaincomplete.util'
local api = require'chaincomplete.api'
local settings = require'chaincomplete.settings'
local timer
local pumvisible = vim.fn.pumvisible
local wrap = vim.schedule_wrap
local can_autocomplete = require'chaincomplete.util'.can_autocomplete
local open_popup = util.keys('<Plug>(AutoComplete)')
--}}}

-------------------------------------------------------------------------------
-- Initialization, enable, disable, toggle
-------------------------------------------------------------------------------
local auto = {}

local function echo(verbose) -- Print current settings {{{1
  if verbose then
    print(string.format('autocomplete = %s', vim.inspect(settings.autocomplete)))
  end
end -- }}}

function auto.set(toggle, args, verbose)
  if toggle then -- if toggle {{{1
    settings.autocomplete.enabled = not settings.autocomplete.enabled
    if not settings.autocomplete.enabled then
      return auto.disable(verbose)
    end

  elseif args == 'on' then -- elseif on {{{1
    settings.autocomplete.enabled = true

  elseif args == 'off' then -- elseif off {{{1
    return auto.disable(verbose)

  elseif args == 'reset' then -- elseif reset {{{1
    settings.autocomplete.prefix = 3
    settings.autocomplete.triggers = { '%w%.', '->' }
    if not settings.autocomplete.enabled then
      return auto.disable(verbose)
    end

  elseif args ~= '' then -- elseif args {{{1
    settings.autocomplete.enabled = true
    settings.autocomplete.prefix = tonumber(args:match('%d+')) or false
    settings.autocomplete.triggers = {}
    for chars in args:gmatch('%D+') do
      table.insert(settings.autocomplete.triggers, chars)
    end
  else -- else print current settings {{{1
    return echo(true)
  end -- }}}
  echo(verbose)
  vim.opt.completeopt:append('noselect')
  settings.noselect = true
  vim.cmd( -- enable autocommands {{{1
    [[
    augroup chaincomplete_auto
    au!
    autocmd InsertCharPre * noautocmd call v:lua.chaincomplete.auto.check()
    autocmd CursorMovedI * noautocmd call v:lua.chaincomplete.auto.start()
    autocmd InsertLeave  * noautocmd call v:lua.chaincomplete.auto.stop()
    augroup END
    ]]) -- }}}
end

function auto.disable(verbose)
  echo(verbose)
  if not settings.autocomplete.enabled then
    return
  end
  settings.autocomplete.enabled = false
  settings.noselect = false
  vim.opt.completeopt:remove('noselect')
  vim.cmd( -- disable autocommands {{{1
    [[
    au! chaincomplete_auto
    aug! chaincomplete_auto
  ]]) -- }}}
end

function auto.check()
  if not settings.noselect then
    vim.opt.completeopt:append('noselect')
    settings.noselect = true
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
    api.feedkeys(open_popup, 'm', false)
  end
end

return auto
