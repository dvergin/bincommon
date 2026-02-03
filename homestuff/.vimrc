"Comment lines begin with double quotes
set autoindent              " indent same as previous line
set autowrite               " auto-save file on move to different edit window/buffer
set background=dark         " Is the background dark or light
set expandtab               " expand tabs to spaces
set hlsearch                " highlight all search results
set ignorecase              " but note also set smartcase
set incsearch               " show matches while searching
set laststatus=2            " show bottom stat line using set statusline fmt
set list                    " show whitespace chars (obeys specs in 'listchars')
"set listchars=eol:`
"set listchars=eol:¶         " specifies how to show various whitespace chars
set listchars=eol:¬
set nowrap                  " turn off line wrapping
set number                  " Show line numbers on the left
set ruler                   " show line/column info in lower right of window
"set runtimepath+=$HOME/.vim/emmet-vim-master
set scrolloff=2             " always show n lines above/below curser
set shiftwidth=3            " when using > or <
set smartcase               " works with set ignorecase
set smartindent             " indent based on sytax (reqires autoindent)
set statusline=%t           " filename
set statusline+=\ (%{&ff})  " file format (i.e. Unix, etc.)
set statusline+=\ %r        " read only flag
set statusline+=\ %m        " modified flag
set statusline+=%=          " push remainder to far right
set statusline+=\ col:%3c   " col #
set statusline+=\ line:%5l  " line #
set statusline+=/%-5L       " total lines
set statusline+=\ %P\ \ \   " percent thru file
set tabstop=3               " tab key = virtual tab = n spaces
set vb                      " visual bell: flash screen instead of a sound
set viminfo='10,            " max files for which marks are saved
set viminfo+=<100,          " max lines saved for each register
set viminfo+=:20,           " command line history lines saved
set viminfo+=%,             " save/restore buffer list
set viminfo+=n~/.viminfo    " location of .viminfo file
set whichwrap=b,<,>,[,],h,l " wrap cursor movement for BAK, arrows, 'h', 'l' in insert & cmd
set wildmenu                " turn on TAB completion
set wildmode=list:longest   " and act like Linux CLI

set foldmethod=indent
set foldlevelstart=99

filetype plugin on

"These work
inoremap jk <ESC>
"Half-width corner brackets for quoting literal text
inoremap [[ ｢
inoremap ]] ｣
nnoremap <Space> i<Space><Esc> " Very handy

imap <F2> <Esc>:bn<CR>
nmap <F2> :bn<CR>

imap <F3> <Esc>:nohls<CR>i
nmap <F3> :nohls<CR>

imap <F4> <ESC>:set nolist<CR>i
nmap <F4> :set nolist<CR>

iabbrev perlheader 
   \#!/usr/bin/perl<CR>
   \use strict;<CR>
   \use warnings;<CR>
   \<c-o>:call getchar()<CR>

iabbrev <h 
   \<!DOCTYPE html><CR>
   \<html><CR>
   \<head><CR>
   \   <title>%</title><CR>
   \<style><CR>
   \<CR>
   \</style><CR>
   \<C-H><C-H><C-H></head><CR>
   \<body><CR>
   \<CR>
   \</body><CR>
   \</html><CR>
   \<ESC>?%<CR>s<c-o>:call getchar()<CR>

au BufEnter nohls

" Restore cursor position when restarting vim
function! ResCur()
  if line("'\"") <= line("$")
    normal! g`"
    return 1
  endif
endfunction
"
augroup resCur
  autocmd!
  autocmd BufWinEnter * call ResCur()
augroup END

" Tell vim to remember certain things when we exit
"  '10  :  marks will be remembered for up to 10 previously edited files
"  "100 :  will save up to 100 lines for each register
"  :20  :  up to 20 lines of command-line history will be remembered
"  %    :  saves and restores the buffer list
"  n... :  where to save the viminfo files

