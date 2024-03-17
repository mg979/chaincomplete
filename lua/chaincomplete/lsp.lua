local bufnr = vim.fn.bufnr
local getline = vim.fn.getline
local split = vim.fn.split
local api = require('nvim-lib').api
local tbl = require('nvim-lib').tbl
local arr = require('nvim-lib').arr
local protocol = vim.lsp.protocol
local insert = table.insert
local sort = table.sort

local lsp = { clients = {} }

local KIND_SNIPPETS = 15

-------------------------------------------------------------------------------
--- From mini.completion.
--- Completion word (textEdit.newText > insertText > label). This doesn't
--- support snippet expansion.
local function get_completion_word(item)
  return (item.textEdit or {}).newText or item.insertText or item.label or ''
end

-------------------------------------------------------------------------------
--- Get an array of characters, and turn lowercase characters into a pattern
--- that matches both uppercase and lowercase.
--- @param chars table
--- @return table
local function smartcase(chars)
  return arr.map(split(chars, '\\zs'), function(_, v)
    return v:find('%l') and '[' .. v:lower() .. v:upper() .. ']' or v
  end)
end

-------------------------------------------------------------------------------
--- Clients for given buffer, or current buffer.
--- @param buf number
--- @return table
function lsp.get_clients(buf)
  return vim.lsp.get_active_clients({ bufnr = buf or bufnr() })
end

-------------------------------------------------------------------------------
--- If there are valid lsp clients attached to current buffer.
--- @return boolean
function lsp.has_client_running()
  for _, c in pairs(lsp.get_clients()) do
    if not c.is_stopped() then
      return true
    end
  end
  return false
end

-------------------------------------------------------------------------------
--- Test if an attached client supports the requested capability.
--- @param capability string
--- @param buf number
--- @return boolean
function lsp.has_capability(capability, buf)
  for _, c in pairs(lsp.get_clients(buf)) do
    if c.server_capabilities[capability] then
      return true
    end
  end
  return false
end

-------------------------------------------------------------------------------
--- Get valid client attached to current buffer.
--- FIXME: only one client per buffer is supported.
--- @return table|nil: client
function lsp.get_buf_client(buf)
  buf = buf or bufnr()
  local client = lsp.clients[buf]
  if client and not client.is_stopped() then
    return client
  end
  for _, c in pairs(lsp.get_clients()) do
    if not c.is_stopped() and c.server_capabilities.completionProvider then
      client = c
      lsp.clients[buf] = c
      break
    end
  end
  return client
end

-------------------------------------------------------------------------------
--- UNUSED
--- If the completed item has lsp informations.
--- @param ud table: item.user_data
--- @return boolean
function lsp.is_lsp_item(ud)
  return ud and type(ud) == 'table' and ud.nvim and ud.nvim.lsp and true
end

-------------------------------------------------------------------------------
--- Whether it's a valid lsp completion trigger character.
--- @param char string
--- @return boolean
function lsp.is_completion_trigger(char)
  local triggers
  for _, client in pairs(lsp.get_clients()) do
    triggers = (client.server_capabilities.completionProvider or {}).triggerCharacters
    if triggers and tbl.contains(triggers, char) then
      return true
    end
  end
  return false
end

-------------------------------------------------------------------------------
--- Lsp trigger characters for buffer.
--- @param buf number
--- @return table|nil
function lsp.completion_triggers(buf)
  local triggers
  for _, client in pairs(lsp.get_clients(buf)) do
    triggers = ((client.server_capabilities or {}).completionProvider or {}).triggerCharacters
    if triggers then
      return triggers
    end
  end
  return nil
end

-------------------------------------------------------------------------------
--- UNUSED
--- If the currently attached client suppors hover documentation.
--- @return boolean
function lsp.has_hover()
  local client = lsp.clients[bufnr()]
  return client and client.server_capabilities.hoverProvider
end

-------------------------------------------------------------------------------
--- UNUSED
--- Position table, as needed by vim.lsp.buf_request.
--- @param item table: item that is being completed
--- @return table position
function lsp.get_position(item)
  local row, col = unpack(api.win_get_cursor(0))
  col = vim.str_utfindex(getline(row), col)
  return { line = row - 1, character = col - string.len(item.word) }
end

-------------------------------------------------------------------------------
--- Generate a fuzzy pattern from characters in `base`. `base` is always at
--- least `from` characters, that is Settings.fuzzy_minchars + 1.
--- Characters up to `from` are not fuzzy, but they are smartcased anyway.
---
--- Examples:
---
---   base = 'abcde', from = 3  --> [aA][bB].-[cC].-[dD].-[eE]
---   base = 'cDGt',  from = 3  --> [cC]D.-G.-[tT]
---
--- @param base string
--- @param from number
--- @return string
function lsp.make_fuzzy_pattern(base, from)
  local pre = base:sub(1, from - 1)
  pre = table.concat(smartcase(pre))
  local fz = table.concat(smartcase(base:sub(from)), '.-')
  return pre .. '.-' .. fz
end

-------------------------------------------------------------------------------
--- From mini.completion.
--- Default items processing function, which takes LSP 'textDocument/completion'
--- response items and word to complete. Its output should be a table of the
--- same nature as input items. The most common use-cases are custom filtering
--- and sorting.
function lsp.process_items(items, base, fuzzy, from)
  local pat = fuzzy and lsp.make_fuzzy_pattern(base, from)
  local res = arr.filter(items, function(_, item)
    -- Keep items which match the base and are not snippets
    if item.kind == KIND_SNIPPETS then
      return false
    else
      local word = get_completion_word(item)
      return fuzzy and word:find(pat) or vim.startswith(word, base)
    end
  end)

  sort(res, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)

  return res
end

-------------------------------------------------------------------------------
--- From mini.completion.
--- Like `vim.lsp.util.text_document_completion_list_to_complete_items`, but it
--- does not filter and sort items. For extra information see 'Response' section:
--- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_completion
function lsp.items_to_complete_items(items)
  if not next(items) then
    return {}
  end

  local res = {}
  local docs, info
  for _, item in pairs(items) do
    -- Documentation info
    docs = item.documentation
    info = type(docs) == 'string' and docs or (docs or {}).value or ''

    insert(res, {
      word = get_completion_word(item),
      abbr = item.label,
      kind = protocol.CompletionItemKind[item.kind] or 'Unknown',
      menu = item.detail or '',
      info = info,
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = { nvim = { lsp = { completion_item = item } } },
    })
  end
  return res
end

-------------------------------------------------------------------------------
--- From mini.completion.
function lsp.process_response(request_result, processor)
  if not request_result then
    return {}
  end

  local res = {}
  for _, item in pairs(request_result) do
    if not item.err and item.result then
      arr.extend(res, processor(item.result) or {})
    end
  end

  return res
end

return lsp

-- vim: ft=lua et ts=2 sw=2 fdm=expr
