"============================================================================
"File:        perl6/jsonerror.vim
"Description: Syntax checking plugin for syntastic.vim. This plugin parses the
"             JSON error output enabled by the environment variable
"             RAKUDO_EXCEPTIONS_HANDLER='JSON'.
"             Minimal Rakudo version needed: 2016.09 (JSON error output
"             added).
"Maintainer:  Claudio Ramirez <pub.claudio at gmail dot com>,
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"
"============================================================================
"
" Security:
"
" This checker runs 'perl6 -c' against your file, which in turn executes
" any BEGIN, and CHECK blocks in your file. This is probably fine if you
" wrote the file yourself, but it can be a problem if you're trying to
" check third party files. If you are 100% willing to let Vim run the code
" in your file, set g:syntastic_enable_perl6_checker to 1 in your vimrc
" to enable this
" checker:
"
"   let g:syntastic_enable_perl6_checker = 1
"
" References:
"
" - https://docs.perl6.org/programs/00-running

"
" Initialization
"
if exists('g:loaded_syntastic_perl6_jsonerror_checker')
    finish
endif
let g:loaded_syntastic_perl6_jsonerror_checker = 1
"Library paths to be add to 'perl6 -I'
if !exists('g:syntastic_perl6lib')
    let g:syntastic_perl6lib = []
endif
" Add support for perl6 filetype
if exists('g:syntastic_extra_filetypes')
    call add(g:syntastic_extra_filetypes, 'perl6')
else
    let g:syntastic_extra_filetypes = ['perl6']
endif

let s:save_cpo = &cpo
set cpo&vim

"
" Functions
"

" Set the perl6 executable
function! SyntaxCheckers_perl6_jsonerror_IsAvailable() dict
    " From .vimrc
    if exists('g:syntastic_perl6_exec')
        silent! call syntastic#util#system(
                    \g:syntastic_perl6_exec . ' -e ' .
                    \syntastic#util#shescape('exit(0)'))
        return v:shell_error == 0
    else
        " Default to perl6
        if !executable(self.getExec())
            return 0
        else
            return 1
        endif
    endif
endfunction

function! SyntaxCheckers_perl6_jsonerror_GetHighlightRegex(item)
    let term = a:item['pattern']
    if term != ''
        let term = substitute(a:item['pattern'], '^\^\\V', '', '')
        let term = substitute(term, '\\\$$', '', '')
        return '\V' . term
    endif
endfunction

function! SyntaxCheckers_perl6_jsonerror_GetLocList() dict
    " Read syntastic_perl6lib path from .vimrc
    if type(g:syntastic_perl6lib) == type('')
        call syntastic#log#oneTimeWarn(
                    \'variable g:syntastic_perl6path should be a list')
        let includes = split(g:syntastic_perl6_jsonerror_lib_path, ',')
    else
        let includes = copy(syntastic#util#var('perl6lib', []))
    endif
    " Support PERL6LIB environment variable
    if $PERL6LIB !=# ''
        let includes += split($PERL6LIB, ':')
    endif

    call map(includes, '"-I" . v:val')

    " Errorformat
    " %f       file name (finds a string)
    " %l       line number (finds a number)
    " %c       column number (finds a number representing character
    "          column of the error, (1 <tab> == 1 character column))
    " %v       virtual column number (finds a number representing
    "          screen column of the error (1 <tab> == 8 screen columns))
    " %t       error type (finds a single character)
    " %n       error number (finds a number)
    " %m       error message (finds a string)
    " %r       matches the 'rest' of a single-line file message %O/P/Q
    " %p       pointer line (finds a sequence of '-', '.', ' ' or
    "          tabs and uses the length for the column number)
    " %*{conv} any scanf non-assignable conversion
    " %%       the single '%' character
    " %s       search text (finds a string)
    let errorformat =
        \ '%f:%l:%c:%m:%s,' .
        \ '%f:%l::%m:,' .
        \ ':%l:%c:%m:%s,' .
        \ ':%l::%m:,' .
        \ ':::%m:'

    " Run info
    let makeprg = self.makeprgBuild({ 'args_before': ['-c'] + includes })

    return SyntasticMake({
        \ 'makeprg': makeprg,
        \ 'errorformat': errorformat,
        \ 'env': { 'RAKUDO_EXCEPTIONS_HANDLER': 'JSON' },
        \ 'defaults': { 'bufnr': bufnr(''), 'type': 'E' },
        \ 'returns': [0, 1],
        \ 'Preprocess': 'Perl6JsonErrorPreprocess' })
endfunction

function! Perl6JsonErrorPreprocess(errors) abort
    let out  = []
    let json = s:_decode_JSON(join(a:errors, ''))
    " debug
    "echo json

    if type(json) == type({})
        try
            for key in keys(json)
                " Create the errorstring
                "'%f:%l:%c:%m:%s'.
                let counter  = 5
                let errormsg = ''
                if has_key(json[key], 'filename') && json[key]['filename'] != ''
                    let errormsg .= json[key]['filename']
                    let counter -= 1
                endif
                let errormsg .= ':'
                if has_key(json[key], 'line') && json[key]['line'] != ''
                    let errormsg .= json[key]['line']
                    let counter -= 1
                endif
                let errormsg .= ':'
                if has_key(json[key], 'pos') && json[key]['pos'] != ''
                    let errormsg .= json[key]['pos']
                    let counter -= 1
                endif
                let errormsg .= ':'
                if has_key(json[key], 'message') && json[key]['message'] != ''
                    let errormsg .= json[key]['message']
                    let counter -= 1
                endif
                let errormsg .= ':'
                if has_key(json[key], 'pre') && json[key]['pre'] != ''
                    let errormsg .= json[key]['pre']
                    let counter -= 1
                endif
                if counter < 5
                    call add(out, errormsg)
                endif
            endfor
        catch /\m^Vim\%((\a\+)\)\=:E716/
            call syntastic#log#warn('checker perl6/json_error: unrecognized error format')
            let out = []
        endtry
    "else
    "    call syntastic#log#warn('checker perl6_jsonerror: empty error message')
    endif
    return out
endfunction

"
" Internal helper functions copied from syntastic
"

" Copied from syntastic's preprocess.vim
function! s:_decode_JSON(json) abort
    if a:json ==# ''
        return []
    endif

    " The following is inspired by https://github.com/MarcWeber/vim-addon-manager and
    " http://stackoverflow.com/questions/17751186/iterating-over-a-string-in-vimscript-or-parse-a-json-file/19105763#19105763
    " A hat tip to Marc Weber for this trick
    if substitute(a:json, '\v\"%(\\.|[^"\\])*\"|true|false|null|[+-]?\d+%(\.\d+%([Ee][+-]?\d+)?)?', '', 'g') !~# "[^,:{}[\\] \t]"
        " JSON artifacts
        let true = 1
        let false = 0
        let null = ''

        try
            let object = eval(a:json)
        catch
            " malformed JSON
            let object = ''
        endtry
    else
        let object = ''
    endif

    return object
endfunction

"
" Register it
"
call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'perl6',
    \ 'name': 'jsonerror',
    \ 'exec': 'perl6',
    \ 'enable': 'enable_perl6_jsonerror_checker'})

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set sw=4 sts=4 et fdm=marker:
