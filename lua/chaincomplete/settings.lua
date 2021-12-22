local settings = {
  border = 'single',
  autocomplete = false,
  docpopup = true,
  chain_lsp = { 'file', 'lsp', 'user', 'c-n' },
  chain_nolsp = { 'file', 'omni', 'user', 'c-n' },
}

if vim.g.chaincomplete and type(vim.g.chaincomplete) == 'table' then
  vim.tbl_extend('force', settings, vim.g.chaincomplete)
end

if type(settings.border) == 'table' then
  settings._brow = string.len(settings.border[2])
  settings._bcol = string.len(settings.border[4])
elseif settings.border == 'none' then
  settings.border = { '', '', '', ' ', '', '', '', ' ' }
  settings._brow = 1
  settings._bcol = 3
else
  settings._brow = 3
  settings._bcol = 3
end

return settings
