local i = require'chaincomplete.intern'

local settings = {
  border = 'single',
  autocomplete = false,
  docinfo = true,
  signature = true,
  use_hover = true,
  resolve_documentation = false,
  replace_partial = false,
  chain_lsp = { 'lsp', 'file', 'user', 'c-n' },
  chain_nolsp = { 'omni', 'file', 'user', 'c-n' },
}

if vim.g.chaincomplete and type(vim.g.chaincomplete) == 'table' then
  settings = vim.tbl_deep_extend('force', settings, vim.g.chaincomplete)
end

-- default settings for popup border
i.set_border_opts(settings.border)

-- default settings for autocompletion
settings.autocomplete = i.set_autocomplete_opts(settings.autocomplete)

-- default settings for other options
i.set_opt('docinfo', settings.docinfo)
i.set_opt('signature', settings.signature)
i.set_opt('use_hover', settings.use_hover)
i.set_opt('resolve_documentation', settings.resolve_documentation)

return settings
