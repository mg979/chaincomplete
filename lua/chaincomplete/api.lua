---@class chaincomplete.api
---@field buf_get_lines function
---@field buf_get_option function
---@field buf_is_valid function
---@field buf_set_lines function
---@field buf_set_option function
---@field close_on_events function
---@field convert_to_markdown function
---@field create_buf function
---@field current_line function
---@field feedkeys function
---@field get_cursor function
---@field make_position_params function
---@field make_text_document_params function
---@field open_win function
---@field pum_getpos function
---@field stylize_markdown function
---@field trim_empty function
---@field win_close function
---@field win_get_config function
---@field win_get_cursor function
---@field win_get_option function
---@field win_is_valid function
---@field win_set_config function
---@field win_set_option function
--- Proxies for nvim api.
local api = {}

api.buf_get_lines             = vim.api.nvim_buf_get_lines
api.buf_get_option            = vim.api.nvim_buf_get_option
api.buf_is_valid              = vim.api.nvim_buf_is_valid
api.buf_set_lines             = vim.api.nvim_buf_set_lines
api.buf_set_option            = vim.api.nvim_buf_set_option
api.close_on_events           = vim.lsp.util.close_preview_autocmd
api.convert_to_markdown       = vim.lsp.util.convert_input_to_markdown_lines
api.create_buf                = vim.api.nvim_create_buf
api.current_line              = vim.api.nvim_get_current_line
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

return api
