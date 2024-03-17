-- Much code from mini.completion.
-- https://github.com/echasnovski/mini.completion

local fn = vim.fn
local api, nvim, tbl = require("nvim-lib")()
local GetChain = require('chaincomplete.chain').GetChain
local lsp = require('chaincomplete.lsp')
local U = require('chaincomplete.util')
local I = require('chaincomplete.info.info')
local W = require('chaincomplete.info.window')

local M = {}

local Opts

-- Cache for completion item info
local Signature = {
  bufnr = nil,
  event = nil,
  id = 0,
  timer = vim.loop.new_timer(),
  winnr = nil,
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

vim.cmd('hi default SignatureActiveParameter cterm=underline gui=underline')

-------------------------------------------------------------------------------
--- Character to the left of the cursor.
--- @return string
local function get_left_char()
  local line = api.get_current_line()
  local coln = api.win_get_cursor(0)[2]

  return string.sub(line, coln, coln)
end

-------------------------------------------------------------------------------
--- Create or reuse buffer for floating window.
--- @return number: buffer number
local function signature_make_buf()
  if not Signature.bufnr or not api.buf_is_valid(Signature.bufnr) then
    Signature.bufnr = api.create_buf(false, true)
  end
  if not Signature.syn or Signature.syn ~= api.buf_get_option(fn.bufnr(), 'syntax') then
    Signature.syn = vim.bo.filetype
    api.buf_set_option(Signature.bufnr, 'syntax', Signature.syn)
  end
  return Signature.bufnr
end

-------------------------------------------------------------------------------
--- Process signature response.
--- @param response table
--- @return table
local function process_signature_response(response)
  if not response.signatures or not next(response.signatures) then
    return {}
  end

  -- Get active signature (based on textDocument/signatureHelp specification)
  local signature_id = response.activeSignature or 0
  -- This is according to specification:
  -- "If ... value lies outside ... defaults to zero"
  local n_signatures = tbl.count(response.signatures or {})
  if signature_id < 0 or signature_id >= n_signatures then
    signature_id = 0
  end
  local signature = response.signatures[signature_id + 1]

  -- Get displayed signature label
  local signature_label = signature.label

  -- Get start and end of active parameter (for highlighting)
  local hl_range = {}
  local n_params = tbl.count(signature.parameters or {})

  -- Take values in this order because data inside signature takes priority
  local parameter_id = signature.activeParameter
    or response.activeParameter
    or 0
  local param_id_inrange = parameter_id >= 0 and parameter_id < n_params

  -- Computing active parameter only when parameter id is inside bounds is not
  -- strictly based on specification, as currently (v3.16) it says to treat
  -- out-of-bounds value as first parameter. However, some clients seems to use
  -- those values to indicate that nothing needs to be highlighted.
  -- Sources:
  -- https://github.com/microsoft/pyright/pull/1876
  -- https://github.com/microsoft/language-server-protocol/issues/1271
  if n_params > 0 and param_id_inrange then
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
  -- `arr.extend()` and the whole inner table is a target value here.
  return { { label = signature_label, hl_range = hl_range } }
end

-------------------------------------------------------------------------------
--- Lines for the signature window.
--- @return table
local function signature_window_lines()
  local signature_data =
    lsp.process_response(Signature.lsp.result, process_signature_response)
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

-------------------------------------------------------------------------------
--- Make options for open_win().
--- @return table
local function signature_window_opts()
  local lines = api.buf_get_lines(Signature.bufnr, 0, -1, {})
  local height, width = I.floating_dimensions(lines, Opts.height, Opts.width)

  -- Compute position
  local win_line = fn.winline()
  local offset = Opts.border == 'none' and 0 or 2
  local space_above = win_line - 1 - offset
  local space_below = fn.winheight(0) - win_line - offset

  local anchor, row, space
  if height <= space_above or space_below <= space_above then
    anchor, row, space = 'SW', 0, space_above
  else
    anchor, row, space = 'NW', 1, space_below
  end

  -- Possibly adjust floating window dimensions to fit screen
  if space < height then
    height, width = I.floating_dimensions(lines, space, Opts.width)
  end

  -- Get zero-indexed current cursor position
  local bufpos = api.win_get_cursor(0)
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
    border = Opts.border,
  }
end

-------------------------------------------------------------------------------
--- Open signature window.
local function show_signature_window()
  -- If there is no received LSP result, make request and exit {{{1
  if Signature.lsp.status ~= 'received' then
    local current_id = Signature.lsp.id + 1
    Signature.lsp.id = current_id
    Signature.lsp.status = 'sent'

    local cancel_fun = vim.lsp.buf_request_all(
      api.get_current_buf(),
      'textDocument/signatureHelp',
      U.make_position_params(),
      function(result)
        if not I.is_lsp_current(Signature, current_id) then
          return
        end

        Signature.lsp.status = 'received'
        Signature.lsp.result = result

        -- Trigger `show_signature_window` again to take 'received' route
        show_signature_window()
      end
    )

    -- Cache cancel function to disable requests when they are not needed
    Signature.lsp.cancel_fun = cancel_fun
    return
  end -- }}}

  -- Ensure that window doesn't open when it shouldn't
  if not U.is_insert_mode() then
    I.close_action_window(Signature)
    return
  end

  -- Make lines to show in floating window
  local lines, hl_ranges = signature_window_lines()
  Signature.lsp.status = 'done'

  -- Close window and exit if there is nothing to show
  if not lines or I.is_whitespace(lines) then
    I.close_action_window(Signature)
    return
  end

  Signature.bufnr = signature_make_buf()

  nvim.setlines(Signature.bufnr, lines)

  -- Add highlighting of active parameter
  for i, hl_range in ipairs(hl_ranges) do
    if next(hl_range) and hl_range.first and hl_range.last then
      api.buf_add_highlight(
        Signature.bufnr,
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
  if Signature.winnr and cur_text == Signature.text then
    return
  end

  -- Cache lines for later checks if window should be reopened
  Signature.text = cur_text

  Signature.winnr =
    W.open_signature(Signature.bufnr, Signature.winnr, signature_window_opts())
end

-------------------------------------------------------------------------------
--- Show signature.
function M.ShowSignature()
  Opts = GetChain().signature
  if not Opts then
    return
  end

  Signature.timer:stop()

  if not get_left_char():match('[(,]') then
    return
  end

  Signature.timer:start(
    Opts.delay or 50,
    0,
    vim.schedule_wrap(show_signature_window)
  )
end

-------------------------------------------------------------------------------
--- Close signature window, reset timer.
function M.CloseSignature()
  Signature.text = nil
  Signature.timer:stop()
  I.cancel_lsp({ Signature })
  I.close_action_window(Signature)
end

return M
-- vim: ft=lua et ts=2 sw=2 fdm=marker
