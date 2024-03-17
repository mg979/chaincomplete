local Settings = require('chaincomplete.settings').settings
local GetChain = require('chaincomplete.chain').GetChain
local lsp = require("chaincomplete.lsp")
local U = require('chaincomplete.util')

local bufnr = vim.fn.bufnr

local O = {}

local omnifunc_items = {}

--- From mini.completion.
function O.omnifunc_sync(findstart, _, fuzzy)
  local chain = GetChain()
  if not chain.lsp then
    return findstart == 1 and -3 or {}
  end

  if findstart == 1 then
    local start, prefix = U.get_completion_start()
    local params = U.make_position_params()

    -- send request for the first two characters, the rest will be fuzzy-matched
    -- totally ignoring multibyte characters
    local minchars = Settings.fuzzy_minchars or 2
    if fuzzy and #prefix > minchars then
      params.position.character = params.position.character - #prefix + minchars
    else
      -- no point in using fuzzy matching at all
      fuzzy = false
    end

    local result = vim.lsp.buf_request_sync(
      bufnr(),
      'textDocument/completion',
      params,
      1000
    )

    omnifunc_items = lsp.process_response(result, function(response)
      -- Response can be `CompletionList` with 'items' field or `CompletionItem[]`
      local items = response.items or response
      if type(items) ~= "table" then
        return {}
      end
      items = Settings.process_items(items, prefix, fuzzy, minchars + 1)
      return lsp.items_to_complete_items(items)
    end)

    return start
  end

  return omnifunc_items
end

function O.omnifunc_sync_fuzzy(findstart)
  if findstart == 1 then
    return O.omnifunc_sync(1, '', true)
  end
  return omnifunc_items
end

return O
