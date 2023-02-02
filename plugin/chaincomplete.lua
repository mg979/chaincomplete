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
vim.g.loaded_chaincomplete = true

-- Needed for popup check
vim.opt.completeopt:append("menuone")

-- Initialize chain on every InsertEnter.
vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    require("chaincomplete").init()
  end,
})

local command = vim.api.nvim_create_user_command
local map = vim.keymap.set

-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------

local chain_c = { "settings", "reset" }
local auto_c = { "triggers", "on", "off", "reset" }

command("ChainComplete", function(cmd)
  require("chaincomplete").set_chain(cmd.args, cmd.bang, true)
end, {
  bang = true,
  nargs = "?",
  complete = function(a)
    return vim.tbl_filter(function(v)
      return v:find("^" .. a)
    end, chain_c)
  end,
})

command("AutoComplete", function(cmd)
  require("chaincomplete").auto.set(cmd.bang, cmd.args, cmd.mods == "verbose")
end, {
  bang = true,
  nargs = "?",
  complete = function(a)
    return vim.tbl_filter(function(v)
      return v:find("^" .. a)
    end, auto_c)
  end,
})

-------------------------------------------------------------------------------
-- Mappings
-------------------------------------------------------------------------------

map("i", "<Plug>(AutoComplete)", "<C-r>=v:lua.Chaincomplete.complete()<CR>", { silent = true })
map("i", "<Plug>(ChainComplete)", "<C-r>=v:lua.Chaincomplete.complete(v:false, v:true)<CR>", { silent = true })
map("i", "<Plug>(ChainAdvance)", "<C-r>=v:lua.Chaincomplete.advance()<CR>", { silent = true })
map("i", "<Plug>(ChainResume)", "<C-g><C-g><C-r>=v:lua.Chaincomplete.resume()<CR>", { silent = true })

if vim.g.chaincomplete_mappings == true then
  if vim.fn.hasmapto("<Plug>(ChainComplete)") == 0 then
    map("i", "<Tab>", "<Plug>(ChainComplete)")
  end
  if vim.fn.hasmapto("<Plug>(ChainAdvance)") == 0 then
    map("i", "<C-j>", "<Plug>(ChainAdvance)")
  end
end
