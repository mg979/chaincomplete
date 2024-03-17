-- ===========================================================================
-- Description: chained completion plugin
-- File:        chaincomplete.lua
-- Author:      Gianmaria Bajo <mg1979@git.gmail.com>
-- License:     MIT
-- Created:     gio 02 feb 2023
-- ===========================================================================

if vim.g.loaded_chaincomplete then
  return
end
vim.g.loaded_chaincomplete = 1

local nvim = require('nvim-lib').nvim

-- Initialize chain on every InsertEnter.
nvim.augroup('chaincomplete')({
  {
    'InsertEnter',
    callback = function()
      vim.g.loaded_chaincomplete = 2
      require('chaincomplete.settings').setup()
      require('chaincomplete').Init()
    end,
  },
})

-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------

nvim.commands({

  ChainComplete = {
    function(cmd)
      require('chaincomplete.commands').ChainComplete(cmd.args, cmd.bang, true)
    end,
    bang = true,
    nargs = '?',
    complete = function(a)
      return require('nvim-lib').arr.filter(
        { 'settings', 'reset' },
        function(_, v)
          return v:find('^' .. a)
        end
      )
    end,
  },

  AutoComplete = {
    function(cmd)
      require('chaincomplete.commands').AutoComplete(
        cmd.bang,
        cmd.args,
        cmd.mods
      )
    end,
    bang = true,
    nargs = '?',
    complete = function(a)
      return require('nvim-lib').arr.filter(
        { 'notriggers', 'on', 'off', 'toggle' },
        function(_, v)
          return v:find('^' .. a)
        end
      )
    end,
  },
})

-------------------------------------------------------------------------------
-- Mappings
-------------------------------------------------------------------------------

local map = vim.keymap.set

map(
  'i',
  '<Plug>(AutoComplete)',
  '<C-r>=v:lua.Chaincomplete.Complete()<CR>',
  { silent = true }
)
map(
  'i',
  '<Plug>(ChainComplete)',
  '<C-r>=v:lua.Chaincomplete.Complete(0)<CR>',
  { silent = true }
)
map(
  'i',
  '<Plug>(ChainAdvance)',
  '<C-r>=v:lua.Chaincomplete.Complete(1)<CR>',
  { silent = true }
)
map(
  'i',
  '<Plug>(ChainResume)',
  '<C-g><C-g><C-r>=v:lua.Chaincomplete.Complete(3)<CR>',
  { silent = true }
)
