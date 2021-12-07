local settings = {
  autocomplete = false,
}

if vim.g.chaincomplete and type(vim.g.chaincomplete) == 'table' then
  vim.tbl_extend('force', settings, vim.g.chaincomplete)
end

return settings
