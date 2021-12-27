local settings = {
  border = 'single',
  autocomplete = false,
  docpopup = true,
  info = true,
  signature = true,
  use_hover = true,
  resolve_documentation = false,
  chain_lsp = { 'file', 'lsp', 'user', 'c-n' },
  chain_nolsp = { 'file', 'omni', 'user', 'c-n' },
}

-- noselect flag, used by autocompletion
settings.noselect = false

if vim.g.chaincomplete and type(vim.g.chaincomplete) == 'table' then
  vim.tbl_extend('force', settings, vim.g.chaincomplete)
end

-- default settings for popup border
if type(settings.border) == 'table' then
  settings._brow = string.len(settings.border[2])
  settings._bcol = string.len(settings.border[4])
elseif settings.border == 'sides' then
  settings.border = { '', '', '', ' ', '', '', '', ' ' }
  settings._brow = 1
  settings._bcol = 3
elseif settings.border == 'none' then
  settings._brow = 1
  settings._bcol = 1
else
  settings._brow = 3
  settings._bcol = 3
end

-- default settings for autocompletion
if type(settings.autocomplete) ~= 'table' then
  settings.autocomplete = {
    enabled = settings.autocomplete and true or false,
    prefix = 3,
    triggers = { '%w%.', '->' },
  }
end

-- Using tables with filetypes
if type(settings.info) == 'table' then
  for k, v in ipairs(settings.info) do
    settings.info[v] = true
    settings[k] = nil
  end
else
  settings.info = {['*'] = settings.info}
end

if type(settings.signature) == 'table' then
  for k, v in ipairs(settings.signature) do
    settings.signature[v] = true
    settings[k] = nil
  end
else
  settings.signature = {['*'] = settings.signature}
end

if type(settings.use_hover) == 'table' then
  for k, v in ipairs(settings.use_hover) do
    settings.use_hover[v] = true
    settings[k] = nil
  end
else
  settings.use_hover = {['*'] = settings.use_hover}
end

if type(settings.resolve_documentation) == 'table' then
  for k, v in ipairs(settings.resolve_documentation) do
    settings.resolve_documentation[v] = true
    settings[k] = nil
  end
else
  settings.resolve_documentation = {['*'] = settings.resolve_documentation}
end

return settings
