" Set up +python3 support.
" Use these instructions:
"   $ python3 -m venv ~/.vim/pynvim
"   $ . ~/.vim/pynvim/bin/activate
"   $ pip3 install -U pynvim
let g:python3_host_prog = '~/.vim/pynvim/bin/python3'

" Source the vim configuration.
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

" Using fzf and the like causes the "Press Enter" prompt. That's annoying, so
" disable that by not showing the command.
set noshowcmd
