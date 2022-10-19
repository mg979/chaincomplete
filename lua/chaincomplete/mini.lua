-- Based on mini.nvim
-- MIT License Copyright (c) 2021 Evgeni Chasnovski

local intern = require'chaincomplete.intern'
local ut = require'chaincomplete.util'
local win = require'chaincomplete.floatwin'
local api = require'chaincomplete.api'
local lsp = require'chaincomplete.lsp'
local util = require'chaincomplete.util'
local fn = vim.fn
local pumvisible = fn.pumvisible
local mode = fn.mode
local vmatch = fn.match

local capabilities, completionProvider, hoverProvider, signatureHelpProvider = lsp.providers()

-- Module definition ==========================================================
local mini = {}
local H = {}
local config

--- Module setup
---
---@param config table: Module config table.
function mini.setup(opts)
  -- Set flags for current insert mode session already
  mini.init()

  -- Setup module behavior
  vim.cmd(
    [[augroup mini
        au!
        au CompleteChanged * lua chaincomplete.mini.auto_info()
        au InsertEnter     * lua chaincomplete.mini.auto_signature()
        au CursorMovedI    * lua chaincomplete.mini.auto_signature()
        au InsertLeavePre  * lua chaincomplete.mini.stop()
        au CompleteDonePre * lua chaincomplete.mini.stop({'info'})
        au InsertCharPre   * lua chaincomplete.mini.on_char_pre()
        au TextChangedI    * lua chaincomplete.mini.on_text_changed_i()
        au TextChangedP    * lua chaincomplete.mini.on_text_changed_p()
        au InsertEnter     * lua chaincomplete.mini.init()
      augroup END]]
  )

  -- Create highlighting
  vim.cmd([[hi default SignatureActiveParameter term=underline cterm=underline gui=underline]])
end

-- Module functionality =======================================================

function mini.init()
  local s, ft, ac = intern, vim.o.filetype, intern.autocomplete
  H.has_completion = lsp.has_capability(completionProvider)
  H.resolve_doc = s.get_opt('resolve_documentation', ft)
  H.use_info = s.get_opt('docinfo', ft)
  H.use_sighelp = lsp.has_capability(signatureHelpProvider) and s.get_opt('signature', ft)
  H.use_hover = lsp.has_capability(hoverProvider) and s.get_opt('use_hover', ft)
  s.trigpats = ac.trigpats and (ac.trigpats[ft] or ac.trigpats['*'])
end

--- Auto completion entry information
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |mini.setup|.
function mini.auto_info()
  if not H.use_info then
    return
  end

  H.info.timer:stop()

  -- Defer execution because of textlock during `CompleteChanged` event
  -- Don't stop timer when closing info window because it is needed
  vim.defer_fn(function()
    H.close_action_window(H.info, true, true)
  end, 0)

  -- Stop current LSP request that tries to get not current data
  H.cancel_lsp({ H.info })

  -- Update metadata before leaving to register a `CompleteChanged` event
  H.info.event = vim.v.event
  H.info.id = H.info.id + 1

  -- Don't event try to show info if nothing is selected in popup
  if vim.tbl_isempty(H.info.event.completed_item) then
    return H.close_action_window(H.info, true)
  end

  H.info.timer:start(config.delay.info, 0, vim.schedule_wrap(H.show_info_window))
end

--- Auto function signature
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |mini.setup|.
function mini.auto_signature()
  if not H.use_sighelp then
    return
  end

  H.signature.timer:stop()

  if not util.get_left_char():match('[(,]') then
    return
  end

  H.signature.timer:start(config.delay.signature, 0, vim.schedule_wrap(H.show_signature_window))
end

--- Stop actions
---
--- This stops currently active (because of module delay or LSP answer delay)
--- actions.
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |mini.setup|.
---
---@param actions table: Array containing any of 'completion', 'info', or 'signature' string.
function mini.stop(actions)
  actions = actions or { 'info', 'signature' }
  for _, n in pairs(actions) do
    H.stop_actions[n]()
  end
end

--- Act on every TextChangedI.
function mini.on_text_changed_i()
  -- Track Insert mode changes
  H.text_changed_id = H.text_changed_id + 1

  -- Stop 'info' processes in case no completion event is triggered but popup
  -- is not visible. See https://github.com/neovim/neovim/issues/15077
  H.stop_info()
end

--- Act on every TextChangedP.
function mini.on_text_changed_p()
  -- Track Insert mode changes
  H.text_changed_id = H.text_changed_id + 1
end

--- Act on every InsertCharPre.
function mini.on_char_pre()
  H.char = vim.v.char
end

--- Function which replaces omnifunc.
function mini.omnifunc(findstart, base)
  -- Early return
  if not H.has_completion then
    if findstart == 1 then
      return -3
    else
      return {}
    end
  end

  if findstart == 1 then
    return H.get_completion_start()
  end

	local result = vim.lsp.buf_request_sync(
    api.current_buf(),
    "textDocument/completion",
    vim.lsp.util.make_position_params(),
    500
  )

  local words = H.process_lsp_response(result, function(response)
    -- Response can be `CompletionList` with 'items' field or `CompletionItem[]`
    local items = response.items or response
    if type(items) ~= "table" then
      return {}
    end
    items = config.process_items(items, base)
    return H.lsp_completion_response_items_to_complete_items(items)
  end)

  if not vim.tbl_isempty(words) then
    return words
  end
  return {}
end

-- Helper data ================================================================

-- Track Insert mode changes
H.text_changed_id = 0

-- Caches for different actions -----------------------------------------------
-- Field `lsp` is a table describing state of all used LSP requests. It has the
-- following structure:
-- - id: identifier (consecutive numbers).
-- - status: status. One of 'sent', 'received', 'done', 'canceled'.
-- - result: result of request.
-- - cancel_fun: function which cancels current request.

-- Cache for completion item info
H.info = {
  bufnr = nil,
  event = nil,
  id = 0,
  timer = vim.loop.new_timer(),
  winnr = nil,
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

-- Cache for signature help
H.signature = {
  bufnr = nil,
  text = nil,
  timer = vim.loop.new_timer(),
  winnr = nil,
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

-- Helper functionality =======================================================

--- Default items processing function, which takes LSP
--- 'textDocument/completion' response items and word to complete. Its output
--- should be a table of the same nature as input items. The most common
--- use-cases are custom filtering and sorting.
function H.process_items(items, base)
  local res = vim.tbl_filter(function(item)
    -- Keep items which match the base and are not snippets
    return vim.startswith(H.get_completion_word(item), base) and item.kind ~= 15
  end, items)

  table.sort(res, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)

  return res
end

-- Stop actions ---------------------------------------------------------------
function H.stop_info()
  -- Id update is needed to notify that all previous work is not current
  H.info.id = H.info.id + 1
  H.info.timer:stop()
  H.cancel_lsp({ H.info })
  H.close_action_window(H.info)
end

function H.stop_signature()
  H.signature.text = nil
  H.signature.timer:stop()
  H.cancel_lsp({ H.signature })
  H.close_action_window(H.signature)
end

H.stop_actions = {
  info = H.stop_info,
  signature = H.stop_signature,
}

-- LSP ------------------------------------------------------------------------
function H.cancel_lsp(caches)
  caches = caches or { H.info, H.signature }
  for _, c in pairs(caches) do
    if vim.tbl_contains({ 'sent', 'received' }, c.lsp.status) then
      if c.lsp.cancel_fun then
        c.lsp.cancel_fun()
      end
      c.lsp.status = 'canceled'
    end
  end
end

function H.process_lsp_response(request_result, processor)
  if not request_result then
    return {}
  end

  local res = {}
  for _, item in pairs(request_result) do
    if not item.err and item.result then
      vim.list_extend(res, processor(item.result) or {})
    end
  end

  return res
end

function H.is_lsp_current(cache, id)
  return cache.lsp.id == id and cache.lsp.status == 'sent'
end

-- Completion -----------------------------------------------------------------
-- This is a truncated version of
-- `vim.lsp.util.text_document_completion_list_to_complete_items` which does
-- not filter and sort items.
-- For extra information see 'Response' section:
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_completion
function H.lsp_completion_response_items_to_complete_items(items)
  if vim.tbl_count(items) == 0 then
    return {}
  end

  local res = {}
  local docs, info
  for _, item in pairs(items) do
    -- Documentation info
    docs = item.documentation
    if type(docs) == 'string' then
      info = docs
    else
      info = (docs or {}).value
    end

    table.insert(res, {
      word = H.get_completion_word(item),
      abbr = item.label,
      kind = vim.lsp.protocol.CompletionItemKind[item.kind] or 'Unknown',
      menu = item.detail or '',
      info = info or '',
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = { nvim = { lsp = { completion_item = item } } },
    })
  end
  return res
end

function H.get_completion_word(item)
  -- Completion word (textEdit.newText > insertText > label). This doesn't
  -- support snippet expansion.
  return (item.textEdit or {}).newText or item.insertText or item.label or ''
end

-- Completion item info -------------------------------------------------------
function H.show_info_window()
  local event = H.info.event
  if not event then
    return H.close_action_window(H.info, true)
  end

  -- Try first to take lines from LSP request result.
  local lines
  if H.info.lsp.status == 'received' then
    lines = H.process_lsp_response(H.info.lsp.result, function(res)
      local doc = H.use_hover and (res.contents or {}).value or res.documentation
      if not doc then
        return H.close_action_window(H.info, true)
      end
      return ut.sanitize_markdown(api.trim_empty(api.convert_to_markdown(doc)))
    end)
    H.info.lsp.status = 'done'
  else
    lines = H.info_window_lines(H.info.id)
  end

  -- Don't show anything if there is nothing to show, but keep window open if
  -- request has been sent and still waiting for response
  if not lines or H.is_whitespace(lines) then
    return H.close_action_window(H.info, true, H.info.lsp.status == 'sent')
  end

  -- Defer execution because of textlock during `CompleteChanged` event
  vim.defer_fn(function()
    -- Ensure that window doesn't open when it shouldn't be
    if not (pumvisible() == 1 and H.is_insert_mode()) then
      return
    end
    H.info.winnr = win.open_info(H.make_buf(H.info), lines, H.info.winnr)
  end, 0)
end

function H.info_non_lsp_lines(item)
  local text = item.info or ''
  if not H.is_whitespace(text) then
    -- Use `<text></text>` to be properly processed by `stylize_markdown()`
    local lines = { '<text>' }
    vim.list_extend(lines, vim.split(text, '\n', false))
    table.insert(lines, '</text>')
    return lines
  end
end

function H.info_window_lines(info_id)
  -- Try to use 'info' field of Neovim's completion item
  local item = (H.info.event or {}).completed_item or {}

  -- Try to get documentation from LSP's initial completion result
  local lsp_item = (((item.user_data or {}).nvim or {}).lsp or {}).completion_item
  -- If there is no LSP's completion item, then there is no point to proceed
  if not lsp_item then
    return H.info_non_lsp_lines(item)
  end

  local params, req

  if not H.use_hover then
    local doc = lsp_item.documentation
    if doc then
      return api.trim_empty(api.convert_to_markdown(doc))
    elseif not H.resolve_doc then
      return {}
    end
    params, req = lsp_item, 'completionItem/resolve'
  else
    params, req = api.make_position_params(), 'textDocument/hover'
  end

  -- Finally, try request to resolve current completion to add documentation

  local current_id = H.info.lsp.id + 1
  H.info.lsp.id = current_id
  H.info.lsp.status = 'sent'

  local cancel_fun = vim.lsp.buf_request_all(
    api.current_buf(), req, params, function(result)
    -- Don't do anything if there is other LSP request in action
    if not H.is_lsp_current(H.info, current_id) then
      return
    end

    H.info.lsp.status = 'received'

    -- Don't do anything if completion item was changed
    if H.info.id ~= info_id then
      return
    end

    H.info.lsp.result = result
    H.show_info_window()
  end)

  H.info.lsp.cancel_fun = cancel_fun

  return nil
end

-- Signature help -------------------------------------------------------------
function H.show_signature_window()
  -- If there is no received LSP result, make request and exit
  if H.signature.lsp.status ~= 'received' then
    local current_id = H.signature.lsp.id + 1
    H.signature.lsp.id = current_id
    H.signature.lsp.status = 'sent'

    local params = vim.lsp.util.make_position_params()

    local cancel_fun = vim.lsp.buf_request_all(
      api.current_buf(), 'textDocument/signatureHelp', params, function(result)
      if not H.is_lsp_current(H.signature, current_id) then
        return
      end

      H.signature.lsp.status = 'received'
      H.signature.lsp.result = result

      -- Trigger `show_signature` again to take 'received' route
      H.show_signature_window()
    end)

    -- Cache cancel function to disable requests when they are not needed
    H.signature.lsp.cancel_fun = cancel_fun

    return
  end

  -- Make lines to show in floating window
  local lines, hl_ranges = H.signature_window_lines()
  H.signature.lsp.status = 'done'

  -- Close window and exit if there is nothing to show
  if not lines or H.is_whitespace(lines) then
    H.close_action_window(H.signature)
    return
  end

  -- Make markdown code block
  table.insert(lines, 1, '```' .. vim.bo.filetype)
  table.insert(lines, '```')

  H.signature.bufnr = H.make_buf(H.signature)

  -- Add `lines` to signature buffer. Use `wrap_at` to have proper width of
  -- 'non-UTF8' section separators.
  vim.lsp.util.stylize_markdown(
    H.signature.bufnr,
    lines,
    { wrap_at = config.dimensions.signature.width }
  )

  -- Add highlighting of active parameter
  for i, hl_range in ipairs(hl_ranges) do
    if not vim.tbl_isempty(hl_range) and hl_range.first and hl_range.last then
      api.buf_add_highlight(
        H.signature.bufnr,
        -1,
        'SignatureActiveParameter',
        i - 1,
        hl_range.first,
        hl_range.last
      )
    end
  end

  -- If window is already opened and displays the same text, don't reopen it
  local cur_text = table.concat(lines, '\n')
  if H.signature.winnr and cur_text == H.signature.text then
    return
  end

  -- Cache lines for later checks if window should be reopened
  H.signature.text = cur_text

  -- Ensure window is closed
  H.close_action_window(H.signature)

  -- Ensure that window doesn't open when it shouldn't
  if H.is_insert_mode() then
    H.signature.winnr = win.open_signature(
      H.signature.bufnr, H.signature.winnr, H.signature_window_opts())
  end
end

function H.signature_window_lines()
  local signature_data = H.process_lsp_response(H.signature.lsp.result, H.process_signature_response)
  -- Each line is a single-line active signature string from one attached LSP
  -- client. Each highlight range is a table which indicates (if not empty)
  -- what parameter to highlight for every LSP client's signature string.
  local lines, hl_ranges = {}, {}
  for _, t in pairs(signature_data) do
    -- `t` is allowed to be an empty table (in which case nothing is added) or
    -- a table with two entries. This ensures that `hl_range`'s integer index
    -- points to an actual line in future buffer.
    table.insert(lines, t.label)
    table.insert(hl_ranges, t.hl_range)
  end

  return lines, hl_ranges
end

function H.process_signature_response(response)
  if not response.signatures or vim.tbl_isempty(response.signatures) then
    return {}
  end

  -- Get active signature (based on textDocument/signatureHelp specification)
  local signature_id = response.activeSignature or 0
  -- This is according to specification: "If ... value lies outside ...
  -- defaults to zero"
  local n_signatures = vim.tbl_count(response.signatures or {})
  if signature_id < 0 or signature_id >= n_signatures then
    signature_id = 0
  end
  local signature = response.signatures[signature_id + 1]

  -- Get displayed signature label
  local signature_label = signature.label

  -- Get start and end of active parameter (for highlighting)
  local hl_range = {}
  local n_params = vim.tbl_count(signature.parameters or {})
  local has_params = signature.parameters and n_params > 0

  -- Take values in this order because data inside signature takes priority
  local parameter_id = signature.activeParameter or response.activeParameter or 0
  local param_id_inrange = 0 <= parameter_id and parameter_id < n_params

  -- Computing active parameter only when parameter id is inside bounds is not
  -- strictly based on specification, as currently (v3.16) it says to treat
  -- out-of-bounds value as first parameter. However, some clients seems to use
  -- those values to indicate that nothing needs to be highlighted.
  -- Sources:
  -- https://github.com/microsoft/pyright/pull/1876
  -- https://github.com/microsoft/language-server-protocol/issues/1271
  if has_params and param_id_inrange then
    local param_label = signature.parameters[parameter_id + 1].label

    -- Compute highlight range based on type of supplied parameter label: can
    -- be string label which should be a part of signature label or direct start
    -- (inclusive) and end (exclusive) range values
    local first, last = nil, nil
    if type(param_label) == 'string' then
      first, last = signature_label:find(vim.pesc(param_label))
      -- Make zero-indexed and end-exclusive
      if first then
        first, last = first - 1, last
      end
    elseif type(param_label) == 'table' then
      first, last = unpack(param_label)
    end
    if first then
      hl_range = { first = first, last = last }
    end
  end

  -- Return nested table because this will be a second argument of
  -- `vim.list_extend()` and the whole inner table is a target value here.
  return { { label = signature_label, hl_range = hl_range } }
end

function H.signature_window_opts()
  local lines = api.buf_get_lines(H.signature.bufnr, 0, -1, {})
  local height, width = H.floating_dimensions(
    lines,
    config.dimensions.signature.height,
    config.dimensions.signature.width
  )

  -- Compute position
  local win_line = fn.winline()
  local space_above, space_below = win_line - 1, fn.winheight(0) - win_line

  local anchor, row, space
  if height <= space_above or space_below <= space_above then
    anchor, row, space = 'SW', 0, space_above
  else
    anchor, row, space = 'NW', 1, space_below
  end

  -- Possibly adjust floating window dimensions to fit screen
  if space < height then
    height, width = H.floating_dimensions(lines, space, config.dimensions.signature.width)
  end

  -- Get zero-indexed current cursor position
  local bufpos = api.get_cursor(0)
  bufpos[1] = bufpos[1] - 1

  return {
    relative = 'win',
    bufpos = bufpos,
    anchor = anchor,
    row = row,
    col = 0,
    width = width,
    height = height,
    focusable = false,
    style = 'minimal',
  }
end

-- Helpers for floating windows -------------------------------------------

--- Create or reuse buffer for floating window.
--- @param cache table: the kind of window
--- @return number: buffer number
function H.make_buf(cache)
  if not cache.bufnr or not api.buf_is_valid(cache.bufnr) then
    cache.bufnr = api.create_buf(false, true)
  end
  return cache.bufnr
end

---@return number, number: height, width
---@private
function H.floating_dimensions(lines, max_height, max_width)
  -- Simulate how lines will look in window with `wrap` and `linebreak`.
  -- This is not 100% accurate (mostly when multibyte characters are present
  -- manifesting into empty space at bottom), but does the job
  local lines_wrap = {}
  for _, l in pairs(lines) do
    vim.list_extend(lines_wrap, H.wrap_line(l, max_width))
  end
  -- Height is a number of wrapped lines truncated to maximum height
  local height = math.min(#lines_wrap, max_height)

  -- Width is a maximum width of the first `height` wrapped lines truncated to
  -- maximum width
  local width = 0
  local l_width
  for i, l in ipairs(lines_wrap) do
    -- Use `strdisplaywidth()` to account for 'non-UTF8' characters
    l_width = fn.strdisplaywidth(l)
    if i <= height and width < l_width then
      width = l_width
    end
  end
  -- It should already be less that that because of wrapping, so this is "just
  -- in case"
  width = math.min(width, max_width)

  return height, width
end

function H.close_action_window(cache, keep_timer, keep_win)
  if not keep_timer then
    cache.timer:stop()
  end

  if not keep_win then
    if cache.winnr then
      win.close(cache.winnr)
    end
    cache.winnr = nil
  end

  -- For some reason 'buftype' might be reset. Ensure that buffer is scratch.
  if cache.bufnr then
    fn.setbufvar(cache.bufnr, '&buftype', 'nofile')
  end
end

-- Utilities ------------------------------------------------------------------

function H.is_insert_mode()
  return mode():match('[iR]')
end

function H.get_completion_start()
  -- Compute start position of latest keyword (as in `vim.lsp.omnifunc`)
  local pos = api.get_cursor(0)
  local line_to_cursor = api.current_line():sub(1, pos[2])
  return vmatch(line_to_cursor, '\\k*$')
end

function H.is_whitespace(s)
  if type(s) == 'string' then
    return s:find('^%s*$')
  end
  if type(s) == 'table' then
    for _, val in pairs(s) do
      if not H.is_whitespace(val) then
        return false
      end
    end
    return true
  end
  return false
end

-- Simulate splitting single line `l` like how it would look inside window with
-- `wrap` and `linebreak` set to `true`
function H.wrap_line(l, width)
  -- github.com/echasnovski/mini.nvim/commit/d8b52c436a2a7f530eba17dcb645ecada4a9d848
  local breakat_pattern = '[- \t.,;:!?]'
  local res = {}

  local break_id, break_match, width_id
  -- Use `strdisplaywidth()` to account for 'non-UTF8' characters
  while fn.strdisplaywidth(l) > width do
    -- Simulate wrap by looking at breaking character from end of current break
    width_id = vim.str_byteindex(l, width)
    break_match = vmatch(l:sub(1, width_id):reverse(), breakat_pattern)
    -- If no breaking character found, wrap at whole width
    break_id = width_id - (break_match < 0 and 0 or break_match)
    table.insert(res, l:sub(1, break_id))
    l = l:sub(break_id + 1)
  end
  table.insert(res, l)

  return res
end

-- Default configuration. {{{1
config = {
  -- Delay (debounce type, in ms) between certain Neovim event and action.
  -- This can be used to (virtually) disable certain automatic actions by
  -- setting very high delay time (like 10^7).
  delay = { info = 100, signature = 50 },

  -- Maximum dimensions of floating windows for certain actions. Action entry
  -- should be a table with 'height' and 'width' fields.
  dimensions = {
    info = { height = 25, width = 80 },
    signature = { height = 25, width = 80 },
  },

  -- `process_items` should be a function which takes LSP
  -- 'textDocument/completion' response items and word to complete. Its
  -- output should be a table of the same nature as input items. The most
  -- common use-cases are custom filtering and sorting.
  process_items = H.process_items,

  -- Whether to set Vim's settings for better experience
  set_vim_settings = true,
} -- }}}

return mini
