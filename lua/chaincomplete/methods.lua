local Keys = require('nvim-lib').nvim.keycodes

local methods = {
  ['files'] = {
    precond = false,
    keys = Keys.CtrlX .. Keys.CtrlF,
    use_triggers = '/',
  },
  ['omni'] = {
    precond = 'omni',
    keys = Keys.CtrlX .. Keys.CtrlO,
    use_triggers = true,
  },
  ['lsp'] = {
    precond = 'lsp',
    keys = Keys.CtrlX .. Keys.CtrlO,
    omnifunc = 'v:lua.Chaincomplete.omnifunc_sync',
    use_triggers = true,
  },
  ['lspf'] = {
    precond = 'lsp',
    keys = Keys.CtrlX .. Keys.CtrlO,
    omnifunc = 'v:lua.Chaincomplete.omnifunc_sync_fuzzy',
    use_triggers = true,
  },
  ['user'] = {
    precond = 'cfunc',
    keys = Keys.CtrlX .. Keys.CtrlU,
  },
  ['dictionary'] = {
    precond = 'dict',
    keys = Keys.CtrlX .. Keys.CtrlK,
  },
  ['thesaurus'] = {
    precond = 'thesaurus',
    keys = Keys.CtrlX .. Keys.CtrlT,
  },
  ['keyn'] = {
    precond = false,
    keys = Keys.CtrlX .. Keys.CtrlN,
  },
  ['keyp'] = {
    precond = false,
    keys = Keys.CtrlX .. Keys.CtrlP,
    invert = true,
  },
  ['line'] = {
    precond = false,
    keys = Keys.CtrlX .. Keys.CtrlL,
  },
  ['includes'] = {
    precond = false,
    keys = Keys.CtrlX .. Keys.CtrlI,
  },
  ['defines'] = {
    precond = false,
    keys = Keys.CtrlX .. Keys.CtrlD,
  },
  ['tags'] = {
    precond = 'tags',
    keys = Keys.CtrlX .. Keys['<C-]>'],
  },
  ['spell'] = {
    precond = false,
    keys = Keys.CtrlX .. 's',
  },
  ['vim'] = {
    precond = false,
    keys = Keys.CtrlX .. Keys.CtrlV,
  },
  ['c-n'] = {
    precond = false,
    keys = Keys.CtrlN,
  },
  ['c-p'] = {
    precond = false,
    keys = Keys.CtrlP,
    invert = true,
  },
}

return methods

-- vim: ft=lua et ts=2 sw=2 fdm=marker
