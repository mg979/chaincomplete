-- Much code from mini.completion.
-- https://github.com/echasnovski/mini.completion

local fn = vim.fn
local api = require('nvim-lib').api
local arr = require('nvim-lib').arr
local GetChain = require('chaincomplete.chain').GetChain
local lsp = require('chaincomplete.lsp')
local U = require('chaincomplete.util')
local I = require('chaincomplete.info.info')
local W = require('chaincomplete.info.window')

local M = {}

local Opts

-- Cache for completion item info
local Popup = {
  bufnr = nil,
  event = nil,
  id = 0,
  timer = vim.loop.new_timer(),
  winnr = nil,
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}


-------------------------------------------------------------------------------

local function info_non_lsp_lines(item)
  local text = item.info or ''
  if not I.is_whitespace(text) then
    -- Use `<text></text>` to be properly processed by `stylize_markdown()`
    local lines = { '<text>' }
    arr.extend(lines, vim.split(text, '\n', false))
    table.insert(lines, '</text>')
    return lines
  end
end

local function popup_lines(info_id)
  -- Try to use 'info' field of Neovim's completion item
  local item = (Popup.event or {}).completed_item or {}

  -- Try to get documentation from LSP's initial completion result
  local lsp_item = (((item.user_data or {}).nvim or {}).lsp or {}).completion_item

  -- If there is no LSP's completion item, then there is no point to proceed
  if not lsp_item then
    return info_non_lsp_lines(item)
  end

  local params, req

  if not Opts.use_hover then
    local doc = lsp_item.documentation
    if doc then
      return U.convert_to_markdown(doc)
    elseif not Opts.resolve_doc then
      return {}
    end
    params, req = lsp_item, 'completionItem/resolve'
  else
    params, req = U.make_position_params(), 'textDocument/hover'
  end

  -- Finally, try request to resolve current completion to add documentation

  local current_id = Popup.lsp.id + 1
  Popup.lsp.id = current_id
  Popup.lsp.status = 'sent'

  local cancel_fun = vim.lsp.buf_request_all(
    api.get_current_buf(),
    req,
    params,
    function(result)
      -- Don't do anything if there is other LSP request in action
      if not I.is_lsp_current(Popup, current_id) then
        return
      end

      Popup.lsp.status = 'received'

      -- Don't do anything if completion item was changed
      if Popup.id ~= info_id then
        return
      end

      Popup.lsp.result = result
      M.show_info_window()
    end
  )

  Popup.lsp.cancel_fun = cancel_fun

  return nil
end

function M.show_info_window()
  local event = Popup.event
  if not event then
    return I.close_action_window(Popup, true)
  end

  -- Try first to take lines from LSP request result.
  local lines
  if Popup.lsp.status == 'received' then
    lines = lsp.process_response(Popup.lsp.result, function(res)
      local doc = Opts.use_hover and (res.contents or {}).value
        or res.documentation
      if not doc then
        return I.close_action_window(Popup, true)
      end
      return U.sanitize_markdown(doc)
    end)
    Popup.lsp.status = 'done'
  else
    lines = popup_lines(Popup.id)
  end

  -- Don't show anything if there is nothing to show, but keep window open if
  -- request has been sent and still waiting for response
  if not lines or I.is_whitespace(lines) then
    return I.close_action_window(Popup, true, Popup.lsp.status == 'sent')
  end

  -- for i = #lines, 1 do
  --   if not lines[i]:find('%S') then
  --     lines[i] = nil
  --   else
  --     break
  --   end
  -- end
  -- Opts.height = #lines

  -- Defer execution because of textlock during `CompleteChanged` event
  vim.defer_fn(function()
    -- Ensure that window doesn't open when it shouldn't be
    if not (fn.pumvisible() == 1 and U.is_insert_mode()) then
      return
    end
    Popup.winnr = W.open_info(I.make_buf(Popup), lines, Popup.winnr, Opts)
  end, 0)
end

function M.ShowInfo()
  Opts = GetChain().info
  if not Opts then
    return
  end

  Popup.timer:stop()

  -- Defer execution because of textlock during `CompleteChanged` event
  -- Don't stop timer when closing info window because it is needed
  vim.defer_fn(function()
    I.close_action_window(Popup, true, true)
  end, 0)

  -- Stop current LSP request that tries to get not current data
  I.cancel_lsp({ Popup })

  -- Update metadata before leaving to register a `CompleteChanged` event
  Popup.event = vim.v.event
  Popup.id = Popup.id + 1

  -- Don't try to show info if nothing is selected in popup
  if not next(Popup.event.completed_item) then
    return I.close_action_window(Popup, true)
  end

  Popup.timer:start(
    Opts.delay or 200,
    0,
    vim.schedule_wrap(M.show_info_window)
  )
end

function M.CloseInfo()
  -- Id update is needed to notify that all previous work is not current
  Popup.id = Popup.id + 1
  Popup.timer:stop()
  I.cancel_lsp({ Popup })
  I.close_action_window(Popup)
end

return M
