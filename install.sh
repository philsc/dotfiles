#!/usr/bin/env bash

VIMDIR=~/.vim
PATHOGEN=https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim

ROOTDIR=$(readlink -f $0)
ROOTDIR=${ROOTDIR%/*}

function new() {
    echo -ne NEW "$@"
}

function warn() {
    echo -ne WARNING "$@"
}

function info() {
    echo -ne INFO "$@"
}

function error() {
    echo -ne ERROR "$@"
}

function ensure_installed() {
    if ! builtin type "$1" >/dev/null 2>&1; then
        error "$1 is not installed\n"
        exit 1
    fi
}

function setup_symlink() {
    if [[ -L "$2" ]]; then
        info "Symlink $2 already installed\n"
    elif [[ -e "$2" ]]; then
        warn "$2 already exists, but is not a symlink\n"
    else
        new "Installing symlink $2\n"
        ln -s "$ROOTDIR/$1" "$2"
    fi
}

function set_git_config() {
    # Test if the alias already exists
    if git config --global "$1" > /dev/null; then
        info "git config $1 already configured\n"
    else
        git config --global "$1" "$2"
        new "git configured $1\n"
    fi
}

function install_pathogen() {
    if [[ ! -r $VIMDIR/autoload/pathogen.vim ]]; then
        mkdir -p $VIMDIR/autoload
        mkdir -p $VIMDIR/bundle
        curl -Sso $VIMDIR/autoload/pathogen.vim $PATHOGEN
        if (($? == 0)); then
            new "Installed pathogen.vim\n"
        else
            error "Failed to install pathogen.vim\n"
            exit 1
        fi
    fi
}

function install_vim_plugin() {
    # Ensure that pathogen is installed
    install_pathogen

    if [[ -d $VIMDIR/bundle/"$1" ]]; then
        info "Vim plugin $1 already installed\n"
    else
        new "Installing vim plugin $1... "
        git clone "$2" $VIMDIR/bundle/"$1" > /dev/null 2>&1
        if (($? == 0)); then
            echo "done"
        else
            echo "failed"
        fi
    fi
}

ensure_installed "ctags"
ensure_installed "ack"
ensure_installed "git"

setup_symlink ".bash" "$HOME/.bash"
setup_symlink ".git_template" "$HOME/.git_template"
setup_symlink ".tmux.conf" "$HOME/.tmux.conf"
setup_symlink ".vim" $VIMDIR

set_git_config 'init.templatedir' "$HOME/.git_template"
set_git_config 'alias.ctags' '!.git/hooks/ctags'
set_git_config 'alias.graph' 'log --all --graph --oneline --decorate=short'
set_git_config 'color.diff' 'auto'
set_git_config 'color.ui' 'auto'

install_vim_plugin "ctrlp.vim" https://github.com/kien/ctrlp.vim.git
install_vim_plugin "fugitive.vim" https://github.com/tpope/vim-fugitive.git
install_vim_plugin "syntastic" https://github.com/scrooloose/syntastic.git
install_vim_plugin "ultisnips" https://github.com/SirVer/ultisnips.git
install_vim_plugin "surround" https://github.com/tpope/vim-surround.git
install_vim_plugin "ack.vim" https://github.com/mileszs/ack.vim.git
install_vim_plugin "gundo.vim" https://github.com/sjl/gundo.vim.git
