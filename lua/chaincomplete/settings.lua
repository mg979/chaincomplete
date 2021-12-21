local settings = {
  autocomplete = false,
  docpopup = true,
  default_chain_lsp = { 'file', 'lsp', 'user', 'c-n' },
  default_chain_nolsp = { 'file', 'omni', 'user', 'c-n' },
}

if vim.g.chaincomplete and type(vim.g.chaincomplete) == 'table' then
  vim.tbl_extend('force', settings, vim.g.chaincomplete)
end

return settings
