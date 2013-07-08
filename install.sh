#!/usr/bin/env bash

VIMDIR=~/.vim
PATHOGEN=https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim

ROOTDIR=$(readlink -f $0)
ROOTDIR=${ROOTDIR%/*}

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
        info "Installing symlink $2\n"
        ln -s "$ROOTDIR/$1" "$2"
    fi
}

function set_git_config() {
    # Test if the alias already exists
    if git config --global "$1" > /dev/null; then
        info "git config $1 already configured\n"
    else
        git config --global "$1" "$2"
        info "git configured $1\n"
    fi
}

function install_pathogen() {
    if [[ -r $VIMDIR/autoload/pathogen.vim ]]; then
        info "pathogen.vim already installed\n"
    else
        mkdir -p $VIMDIR/autoload
        mkdir -p $VIMDIR/bundle
        curl -Sso $VIMDIR/autoload/pathogen.vim $PATHOGEN
        info "Installed pathogen.vim\n"
    fi
}

function install_vim_plugin() {
    # Ensure that pathogen is installed
    install_pathogen

    if [[ -d $VIMDIR/bundle/"$1" ]]; then
        info "Vim plugin $1 already installed\n"
    else
        info -n "Installing vim plugin $1... "
        git clone "$2" $VIMDIR/bundle/"$1" > /dev/null 2>&1
        info "done\n"
    fi
}

ensure_installed "ctags"

setup_symlink ".vim" $VIMDIR
setup_symlink ".git_template" "$HOME/.git_template"

set_git_config 'init.templatedir' "$HOME/.git_template"
set_git_config 'alias.ctags' '!.git/hooks/ctags'

install_vim_plugin "fugitive.vim" "https://github.com/tpope/vim-fugitive.git"
