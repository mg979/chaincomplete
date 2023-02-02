-- local variables {{{1
local util = require'chaincomplete.util'
local api = require'chaincomplete.api'
local settings = require'chaincomplete.settings'
local intern = require'chaincomplete.intern'
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
  local ac = vim.tbl_extend('keep', {}, intern.autocomplete) -- copy

  if toggle then -- if toggle {{{1
    ac.enabled = not ac.enabled

  elseif args == 'on' then -- elseif on {{{1
    ac.enabled = true

  elseif args == 'off' then -- elseif off {{{1
    ac.enabled = false

  elseif args == 'triggers' then -- elseif triggers {{{1
    ac.enabled = true
    ac.prefix = false

  elseif args == 'reset' then -- elseif reset {{{1
    -- keep the enabled state, but reset all the rest
    ac.prefix = 3
    ac.triggers = nil

  elseif args ~= '' then -- elseif args {{{1
    ac.enabled = true
    ac.prefix = tonumber(args:match('%d+')) or false
    ac.triggers = {}
    for chars in args:gmatch('%p+') do
      table.insert(ac.triggers, chars)
    end
    if #ac.triggers == 0 then
      ac.triggers = nil
    end
  else -- else print current settings {{{1
    return echo(true)
  end -- }}}

  -- update settings
  settings.autocomplete = intern.set_autocomplete_opts(ac)
  echo(verbose)

  if ac.enabled then
		vim.opt.completeopt:append('noselect')
		intern.noselect = true
		vim.cmd( -- enable autocommands {{{1
			[[
			augroup chaincomplete_auto
			au!
			autocmd FileType TelescopePrompt lua vim.b.autocomplete_disabled = true
			autocmd InsertCharPre * noautocmd call v:lua.Chaincomplete.auto.check()
			autocmd TextChangedI * noautocmd call v:lua.Chaincomplete.auto.start()
			autocmd InsertLeave  * noautocmd call v:lua.Chaincomplete.auto.stop()
			autocmd CompleteDonePre * noautocmd call v:lua.Chaincomplete.auto.halt()
			augroup END
			]]) -- }}}
	else
		intern.noselect = false
		vim.opt.completeopt:remove('noselect')
		vim.cmd( -- disable autocommands {{{1
			[[
			silent! au! chaincomplete_auto
			silent! aug! chaincomplete_auto
			]]) -- }}}
  end

end

-------------------------------------------------------------------------------
-- Autocompletion timer
-------------------------------------------------------------------------------

--- Called on InsertCharPre, to ensure 'noselect' flag is enabled.
--- Will also reset the 'halted' flag to resume autocompletion.
function auto.check()
  if not intern.noselect then
    vim.opt.completeopt:append('noselect')
    intern.noselect = true
  end
  auto.halted = false
end

--- Called on text changes in insert mode.
function auto.start()
  auto.stop()
  if not auto.halted and not vim.b.autocomplete_disabled and pumvisible() == 0 then
    timer = vim.loop.new_timer()
    timer:start(100, 0, wrap(auto.complete))
  end
end

--- Stop timer if currently running.
function auto.stop()
  if timer then
    timer:close()
    timer = nil
  end
end

--- Callback of auto.start, to try autocompletion.
function auto.complete()
  auto.stop()
  if pumvisible() == 0 and can_autocomplete() then
    api.feedkeys(open_popup, 'm', false)
  end
end

--- Called on CompleteDone, to prevent immediate retriggering
function auto.halt()
  auto.stop()
  auto.halted = true
end

return auto
