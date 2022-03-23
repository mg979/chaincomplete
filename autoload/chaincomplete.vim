""
" Function: chaincomplete#auto
"
" @param bang: toggle autocompletion
" @param args: arguments for :AutoComplete
" @param verbose: print current settings after command
""
fun! chaincomplete#auto(bang, args, verbose)
    lua chaincomplete = require'chaincomplete'
    let v = a:verbose == 'verbose' ? 'true' : 'false'
    let b = a:bang ? 'true' : 'false'
    exe printf("lua chaincomplete.auto.set(%s, '%s', %s)", b, a:args, v)
endfun

""
" Function: chaincomplete#auto_c
" Command-line completion for :AutoComplete
"
" @param ...: command-line arguments
" Returns: filtered completion
""
function! chaincomplete#auto_c(...) abort
    return filter(['triggers', 'on', 'off', 'reset'], 'v:val =~ a:1')
endfunction

""
" Function: chaincomplete#chain
"
" @param bang: enter chain from input
" @param args: string arguments for :ChainComplete
""
fun! chaincomplete#chain(bang, args)
    lua chaincomplete = require'chaincomplete'
    let b = a:bang ? 'true' : 'false'
    exe printf("lua chaincomplete.set_chain('%s', %s, true)", a:args, b)
endfun

""
" Function: chaincomplete#chain_c
" Command-line completion for :ChainComplete
"
" @param ...: command-line arguments
" Returns: filtered completion
""
function! chaincomplete#chain_c(...) abort
    return filter(['settings', 'reset'], 'v:val =~ a:1')
endfunction
