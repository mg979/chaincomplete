local bufnr = vim.fn.bufnr

local lsp = {}

lsp.clients = {}

function lsp.get_buf_client()
  local client = lsp.clients[bufnr()]
  if client and not client.is_stopped() then
    return client
  end
  for _, c in ipairs(vim.lsp.buf_get_clients()) do
    if not c.is_stopped() and c.server_capabilities.completionProvider then
      lsp.clients[bufnr()] = c
      break
    end
  end
  return lsp.clients[bufnr()]
end

return lsp
