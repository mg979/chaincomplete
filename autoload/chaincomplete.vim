""
" Function: chaincomplete#auto
"
" @param bang: toggle autocompletion
" @param args: arguments for :ChainCompleteAuto
" @param verbose: print current settings after command
""
fun! chaincomplete#auto(bang, args, verbose)
    lua chaincomplete = require'chaincomplete'
    let v = a:verbose == 'verbose' ? 'true' : 'false'
    if a:bang
        exe 'lua chaincomplete.auto.set(true, "' . a:args . '", ' . v .')'
    else
        exe 'lua chaincomplete.auto.set(false, "' . a:args . '", ' . v .')'
    endif
endfun

""
" Function: chaincomplete#chain
"
" @param bang: enter chain from input
" @param args: string arguments for :ChainComplete
""
fun! chaincomplete#chain(bang, args)
    lua chaincomplete = require'chaincomplete'
    if a:bang
        exe 'lua chaincomplete.set(true, "' . a:args . '", true)'
    else
        exe 'lua chaincomplete.set(false, "' . a:args . '", true)'
    endif
endfun

