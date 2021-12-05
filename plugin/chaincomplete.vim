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
" }}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" enable completion for current buffer
command! -bar           ChainCompleteAutoEnable  call s:call('v:lua.chaincomplete.auto.enable(1)')

" disable completion for current buffer
command! -bar           ChainCompleteAutoDisable call s:call('v:lua.chaincomplete.auto.disable(1)')

" toggle completion for current buffer
command! -bar           ChainCompleteAutoToggle  call s:call('v:lua.chaincomplete.auto.toggle()')

" enable completion triggered by dot or ->
command! -bang -nargs=? ChainCompleteAutoTrigger call s:call('v:lua.chaincomplete.dot.init(' . <bang>0 . ', ' . <q-args> . ')')

" show/set/reset chain
command! -bang -nargs=? ChainComplete            call s:call('v:lua.chaincomplete.set(' . <bang>0 . ', ' . <q-args> . ')')

inoremap <silent> <Plug>(ChainComplete)   <C-r>=v:lua.chaincomplete.complete()<CR>
inoremap <silent> <Plug>(ChainAdvance)    <C-r>=v:lua.chaincomplete.advance()<CR>
inoremap <silent> <Plug>(ChainResume)     <C-r>=v:lua.chaincomplete.resume()<CR>

if empty(maparg('<tab>', 'i')) && !hasmapto('<Plug>(ChainComplete)')
    imap <tab>  <Plug>(ChainComplete)
endif

if empty(maparg('<C-j>', 'i')) && !hasmapto('<Plug>(ChainAdvance)')
    imap <C-j>  <Plug>(ChainAdvance)
endif

fun! s:call(func)
    lua chaincomplete = require'chaincomplete'
    exe 'call' a:func
endfun

" Needed for popup check
set completeopt+=menuone

au InsertEnter * ++once lua chaincomplete = require'chaincomplete'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker
