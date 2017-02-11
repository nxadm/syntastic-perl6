# Perl 6 support for vim-syntastic

![Alt text](/../master/syntastic-perl6.png?raw=true "Screenshot")


While the Vim syntax check plugin [syntastic]
(https://github.com/scrooloose/syntastic "Syntastic Vim plugin") offers Perl 5
support, it does not at the moment support Perl 6.  This plugin implements
Perl 6 support (until these changes are incorporated upstream).

Since the 2016.09 Rakudo release, Rakudo supports JSON error support. This is
the minimal version required to use this plugin. This regex-based plugin, used
before 2016.09 will be archived in the branch "regex" in case you have an
older Rakudo version.

## Installation & configuration
You need to install syntastic to use this plugin. Instructions for
[pathogen plugin manager] (https://github.com/tpope/vim-pathogen "vim-pathogen"):
```
$ cd ~/.vim
$ git clone https://github.com/scrooloose/syntastic.git ~/.vim/bundle/synastic
$ git clone https://github.com/nxadm/syntastic-perl6.git ~/.vim/bundle/synastic-perl6
```
Type ":Helptags" in Vim to generate Help Tags.

Syntastic and syntastic-perl6 vimrc configuration (comments start with "):
```
"syntastic syntax checking (see the syntastic documentation)
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

"Perl 6 support
"Optional comma separated list of quoted paths to be included to -I
let g:syntastic_perl6lib = [ 'lib', '../lib' ]
"Optional perl6 binary (defaults to perl6 in your PATH)
"let g:syntastic_perl6_exec = '/opt/rakudo/bin/perl6'
"Register the checker provided by this plugin
let g:syntastic_perl6_checkers = ['jsonerror']
"Enable the perl6 checker (disabled out of the box because of security reasons:
"'perl6 -c' executes the BEGIN and CHECK block of code it parses. This should
"be fine for your own code. See: https://docs.perl6.org/programs/00-running
let g:syntastic_enable_perl6_jsonerror_checker = 1
```
Also, you could check [this blogpost on how to configure Vim to as an Perl6
editor] (https://nxadm.wordpress.com/2016/08/21/vim-as-a-perl-6-editor/).

## Module path of your code
There are two ways of dealing with unknown lib path perl6 errors,
you can populate the g:syntastic_perl6_lib_path, and/or more practically,
you can set the PERL6LIB environment in your shell. E.g. for for sh/bash:
```
$ export PERL6LIB=~/Code/SomePerl6Module/lib:~/Code/SomeOtherPerl6Module/lib
$ vim my_perl6_program.p6
```

## Contribute: make this plugin better
- Send a PR to make the code (vimscript) better where needed.
- Send a PR to add tests for error cases not yet tested (see the t directory).
- Post an issue if you find a bug. In that case copy-paste the error
(e.g. within vim: :!perl6 -c %) and post a sample of the erroneous Perl 6 code
in question.
- Fix bugs.

## Author
nxadm (El_Che @ #perl6 (freenode))

A big thanks to lcd047 (syntasic contributor) for the many pointers and
corrections.
