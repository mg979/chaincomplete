local util = require'chaincomplete.util'

local wordchar_before = util.wordchar_before
local filechar_before = util.filechar_before
local dot_before      = util.dot_before
local arrow_before    = util.arrow_before

local function try_omni() -- {{{1
  return vim.o.omnifunc ~= '' and (
    wordchar_before() or dot_before() or arrow_before()
    )
end

local function try_lsp() -- {{{1
  return next(vim.lsp.buf_get_clients())
end

local function try_user() -- {{{1
  return vim.o.completefunc ~= '' and wordchar_before()
end

local function try_dict() -- {{{1
  return vim.o.dictionary ~= '' and wordchar_before()
end

-- }}}

return {
  ['file'] = {
    can_try = filechar_before,
    keys = '\\<C-x>\\<C-f>'
  },
  ['omni'] = {
    can_try = try_omni,
    keys = '\\<C-x>\\<C-o>',
  },
  ['lsp'] = {
    can_try = try_lsp,
    keys = util.keys('<C-x><C-o>'),
    async = true,
    timeout = 500,
  },
  ['user'] = {
    can_try = try_user,
    keys = '\\<C-x>\\<C-u>',
  },
  ['dict'] = {
    can_try = try_dict,
    keys = '\\<C-x>\\<C-k>',
  },
  ['keyn'] = {
    can_try = wordchar_before,
    keys = '\\<C-x>\\<C-n>',
  },
  ['keyp'] = {
    can_try = wordchar_before,
    keys = '\\<C-x>\\<C-p>',
    invert = true,
  },
  ['line'] = {
    can_try = wordchar_before,
    keys = '\\<C-x>\\<C-l>',
  },
  ['incl'] = {
    can_try = wordchar_before,
    keys = '\\<C-x>\\<C-i>',
  },
  ['defs'] = {
    can_try = wordchar_before,
    keys = '\\<C-x>\\<C-d>',
  },
  ['tags'] = {
    can_try = wordchar_before,
    keys = '\\<C-x>\\<C-]>',
  },
  ['spel'] = {
    can_try = wordchar_before,
    keys = '\\<C-x>s',
  },
  ['vim'] = {
    can_try = wordchar_before,
    keys = '\\<C-x>\\<C-v>',
  },
  ['c-n'] = {
    can_try = wordchar_before,
    keys = '\\<C-n>',
  },
  ['c-p'] = {
    can_try = wordchar_before,
    keys = '\\<C-p>',
    invert = true,
  },
}
