--- Proxies for nvim api.
local api = {}

--- Create autocommands to close floating window.
--- @param events table
--- @param winnr number
local function close_preview_autocmd(events, winnr)
  -- {{{1
  if #events > 0 then
    vim.cmd("autocmd " .. table.concat(events, ',')
      .. " <buffer> ++once lua pcall(vim.api.nvim_win_close, "
      .. winnr .. ", true)")
  end
end
--}}}

api.buf_get_lines             = vim.api.nvim_buf_get_lines
api.buf_get_option            = vim.api.nvim_buf_get_option
api.buf_is_valid              = vim.api.nvim_buf_is_valid
api.buf_set_lines             = vim.api.nvim_buf_set_lines
api.buf_set_option            = vim.api.nvim_buf_set_option
api.buf_add_highlight         = vim.api.nvim_buf_add_highlight
api.close_on_events           = close_preview_autocmd
api.convert_to_markdown       = vim.lsp.util.convert_input_to_markdown_lines
api.create_buf                = vim.api.nvim_create_buf
api.current_line              = vim.api.nvim_get_current_line
api.current_buf               = vim.api.nvim_get_current_buf
api.feedkeys                  = vim.api.nvim_feedkeys
api.get_cursor                = vim.api.nvim_win_get_cursor
api.make_position_params      = vim.lsp.util.make_position_params
api.make_text_document_params = vim.lsp.util.make_text_document_params
api.open_win                  = vim.api.nvim_open_win
api.pum_getpos                = vim.fn.pum_getpos
api.stylize_markdown          = vim.lsp.util.stylize_markdown
api.trim_empty                = vim.lsp.util.trim_empty_lines
api.win_close                 = vim.api.nvim_win_close
api.win_get_config            = vim.api.nvim_win_get_config
api.win_get_cursor            = vim.api.nvim_win_get_cursor
api.win_get_option            = vim.api.nvim_win_get_option
api.win_is_valid              = vim.api.nvim_win_is_valid
api.win_set_config            = vim.api.nvim_win_set_config
api.win_set_option            = vim.api.nvim_win_set_option
api.replace_termcodes         = vim.api.nvim_replace_termcodes

return api
