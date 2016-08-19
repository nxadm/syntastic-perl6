"============================================================================
"File:        perl6.vim
"Description: Syntax checking plugin for syntastic.vim
"Maintainer:  Claudio Ramirez <pub.claudio at gmail dot com>,
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"Ported from: perl6.vim from maintained by 
"             Anthony Carapetis <anthony.carapetis at gmail dot com>,
"             Eric Harmon <http://eharmon.net>
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

"Initialization
if exists('g:syntastic_extra_filetypes')
    call add(g:syntastic_extra_filetypes, 'perl6')
else
    let g:syntastic_extra_filetypes = ['perl6']
endif

if exists('g:loaded_syntastic_perl6_perl6_checker')
    finish
endif
let g:loaded_syntastic_perl6_perl6_checker = 1

"Includes
if !exists('g:syntastic_perl6_lib_path')
    let g:syntastic_perl6_lib_path = []
elseif type(g:syntastic_perl6_lib_path) == type('')
    call syntastic#log#oneTimeWarn('variable g:syntastic_perl6_lib_path should be a list')
        let includes = split(g:syntastic_perl6_lib_path, ',')
    else
        let includes = copy(syntastic#util#var('perl6_lib_path'))
endif

if $PERL6LIB != '' "Support for PERL6LIB shell environment
    let perl6lib = includes + split($PERL6LIB, ':')
    let includes = perl6lib
endif
let g:syntastic_perl6_lib_path = includes

let s:save_cpo = &cpo
set cpo&vim

function! SyntaxCheckers_perl6_perl6_GetLocList() dict " {{{1
    let includes_str = join(map(g:syntastic_perl6_lib_path, '"-I" . v:val'))
    let errorformat = '%f|:|%l|:|%m'
    let makeprg = self.makeprgBuild({ 'args_before': '-c ' . includes_str})
    
    let errors = SyntasticMake({
        \ 'makeprg': makeprg,
        \ 'errorformat': errorformat,
        \ 'Preprocess': 'Perl6Preprocess',
 		\ 'env': { 'RAKUDO_ERROR_COLOR': '' },
        \ 'defaults': {'type': 'E'} })
    if !empty(errors)
        return errors
    endif
    
    let makeprg = self.makeprgBuild({ 'args_before': '-c ' . includes_str })
    
    return SyntasticMake({
        \ 'makeprg': makeprg,
        \ 'errorformat': errorformat,
        \ 'Preprocess': 'Perl6Preprocess',
        \ 'defaults': {'type': 'W'} })
endfunction " }}}1

function! SyntaxCheckers_perl6_perl6_IsAvailable() dict
    if exists('g:syntastic_perl6_interpreter')
        let binary = g:syntastic_perl6_interpreter
    else
        let binary = self.getExecEscaped()
    endif
    return executable(binary)
endfunction

function! Perl6Preprocess(errors) abort
    let out               = [] "List of errors                                  
    let err_str           = {} "Error parts                                     
    let err_str.msg       = '' "We'll concatenate the messages                  
    let file_pat          = 'Error while compiling\s\(.*\)$'                    
    let line_pat_def      = '^at .*:\(\d\+\)$'                                  
    let line_pat_undecl   = '^.* used at line \(\d\+\)'                         
    let ansi_pat          = '\e[[0-9]\+[mK]'                                    
    "Error message for among other undeclared subroutines & names               
    let undeclared_pat    = '^Undeclared\s\+'                                   
    let notfound_pat      = '^Could not find .* at line \(\d\+\) in:'           
                                                                                
    for e in a:errors                                                           
        "Get the filename                                                       
        if match(e, file_pat) > -1                                              
            let parts = matchlist(e, file_pat)                                  
            let err_str.file = parts[1]                                         
        "Get the line number                                                    
        else                                                                    
            if match(e, line_pat_def) > -1                                      
                let parts = matchlist(e, line_pat_def)                          
                let err_str.line = parts[1]                                     
                continue "We only need the line number                          
            endif                                                               
            if match(e, line_pat_undecl) > -1                                   
                "The undeclare line with nr must be added to msg                
                let parts = matchlist(e, line_pat_undecl)                       
                let err_str.line = parts[1]                                     
            endif                                                               
            if match(e, notfound_pat) > -1                                      
                "The unknown line with nr must be added to msg                  
                let parts = matchlist(e, notfound_pat)                          
                let err_str.line = parts[1]                                     
            endif                                                               
            "Add it to the message, ignore empty lines                          
            if match(e, '\S') > -1                                              
                if match(e, '^\s\+') > -1                                       
                    let e = substitute(e,'^\s\+', '', '')                       
                endif                                                           
                if match(e, ansi_pat) > -1                                      
                    let e = substitute(e, ansi_pat, '', 'g')                    
                endif                                                           
                let concat = err_str.msg . e . '␤' "utf8 newline symbol         
                let err_str.msg = concat                                        
            endif                                                               
        endif                                                                   
    endfor                                                                      
                                                                                
    if has_key(err_str, 'line')                                                 
        "Some errors do not show the file name                                  
        if !has_key(err_str, 'file')                                            
            let err_str.file = expand('%p')                                     
        endif                                                                   
        call add(out, err_str.file . '|:|' .                                    
                    \ err_str.line . '|:|' . err_str.msg )                      
    endif                                                                       
                                                                                
    return syntastic#util#unique(out)                                           
endfunction

function! SyntaxCheckers_perl6_perl6_GetHighlightRegex(item)
	" Arrow-eject errors
    let parts = matchlist(a:item['text'], 
		\'------>\s*\(.\{-}\)<HERE>')                         
    if !empty(parts)                                                   
        return '\V' . escape(parts[1], '\')
    endif
	" Default (catches also '^Can only use'
    let term = matchstr(a:item['text'], '\m''\zs.\{-}\ze''')
    if term !=# ''
        return '\V' . escape(term, '\')
    endif
	"Undeclare routines and names
    let term = matchstr(a:item['text'], '\m^Undeclared .\+:\W\zs\S\+\ze')
    if term !=# ''
        return '\V' . escape(term, '\')
    endif
	"Not found modules
    let term = matchstr(a:item['text'], '\mCould not find \zs.\{-}\ze at')
    return term !=# '' ? '\V' . escape(term, '\') : ''
endfunction


"function! SyntaxCheckers_perl6_perl6_GetHighlightRegex(item)
"    let eject_pat     = '------>\s*\(.\{-}\)⏏'
"    let can_only_pat  = "^Can only use '" . '\(.\{-}\)' . "'"
"    let undecl_pat    = '^Undeclared .*:\W\(.\{-}\)\s'
"    let not_found_pat = 'Could not find \(.\{-}\) at'
"    
"    for pat in [ eject_pat, can_only_pat, undecl_pat, not_found_pat ]
"        if match(a:item['text'], pat) > -1 
"            let parts = matchlist(a:item['text'], pat)
"            if !empty(parts)
"                return parts[1]
"            endif
"        endif
"    endfor
"
"    return ''
"endfunction


call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'perl6',
    \ 'name': 'perl6',
    \ 'enable': 'enable_perl6_checker'})

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set sw=4 sts=4 et fdm=marker:
