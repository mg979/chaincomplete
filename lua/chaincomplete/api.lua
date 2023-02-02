--- Proxies for nvim api.

--- Create autocommands to close floating window.
--- @param events table
--- @param winnr number
local function close_preview_autocmd(events, winnr)
  -- {{{1
  if #events > 0 then
    vim.cmd(
      "autocmd "
        .. table.concat(events, ",")
        .. " <buffer> ++once lua pcall(vim.api.nvim_win_close, "
        .. winnr
        .. ", true)"
    )
  end
end
--}}}

return {
  buf_get_lines = vim.api.nvim_buf_get_lines,
  buf_get_option = vim.api.nvim_buf_get_option,
  buf_is_valid = vim.api.nvim_buf_is_valid,
  buf_set_lines = vim.api.nvim_buf_set_lines,
  buf_set_option = vim.api.nvim_buf_set_option,
  buf_add_highlight = vim.api.nvim_buf_add_highlight,
  close_on_events = close_preview_autocmd,
  convert_to_markdown = vim.lsp.util.convert_input_to_markdown_lines,
  create_buf = vim.api.nvim_create_buf,
  current_line = vim.api.nvim_get_current_line,
  current_buf = vim.api.nvim_get_current_buf,
  feedkeys = vim.api.nvim_feedkeys,
  get_cursor = vim.api.nvim_win_get_cursor,
  make_position_params = vim.lsp.util.make_position_params,
  make_text_document_params = vim.lsp.util.make_text_document_params,
  open_win = vim.api.nvim_open_win,
  pum_getpos = vim.fn.pum_getpos,
  stylize_markdown = vim.lsp.util.stylize_markdown,
  trim_empty = vim.lsp.util.trim_empty_lines,
  win_close = vim.api.nvim_win_close,
  win_get_config = vim.api.nvim_win_get_config,
  win_get_cursor = vim.api.nvim_win_get_cursor,
  win_get_option = vim.api.nvim_win_get_option,
  win_is_valid = vim.api.nvim_win_is_valid,
  win_set_config = vim.api.nvim_win_set_config,
  win_set_option = vim.api.nvim_win_set_option,
  replace_termcodes = vim.api.nvim_replace_termcodes,
}
