" ========================================================================///
" Description: chained completion plugin
" File:        chaincomplete.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     gio 10 dicembre 2020 00:16:57
" ========================================================================///

" GUARD {{{1
if !has('nvim') || exists('g:loaded_chaincomplete')
    finish
endif
let g:loaded_chaincomplete = 1
" }}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" autocompletion
command! -bang -nargs=? -complete=customlist,chaincomplete#auto_c AutoComplete  call chaincomplete#auto(<bang>0, <q-args>, <q-mods>)

" show/set/reset chain
command! -bang -nargs=? -complete=customlist,chaincomplete#chain_c ChainComplete call chaincomplete#chain(<bang>0, <q-args>)


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugs and mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

inoremap <silent> <Plug>(AutoComplete)    <C-r>=v:lua.chaincomplete.complete()<CR>
inoremap <silent> <Plug>(ChainComplete)   <C-r>=v:lua.chaincomplete.complete(v:false, v:true)<CR>
inoremap <silent> <Plug>(ChainAdvance)    <C-r>=v:lua.chaincomplete.advance()<CR>
inoremap <silent> <Plug>(ChainResume)     <C-g><C-g><C-r>=v:lua.chaincomplete.resume()<CR>

if empty(maparg('<tab>', 'i')) && !hasmapto('<Plug>(ChainComplete)')
    imap <tab>  <Plug>(ChainComplete)
endif

if empty(maparg('<C-j>', 'i')) && !hasmapto('<Plug>(ChainAdvance)')
    imap <C-j>  <Plug>(ChainAdvance)
endif



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Initialization
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Needed for popup check
set completeopt+=menuone

au InsertEnter * ++once lua chaincomplete = require'chaincomplete'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker
