#!/usr/bin/env bash

VIMDIR=~/.vim
PATHOGEN=https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim

ROOTDIR=$(readlink -f $0)
ROOTDIR=${ROOTDIR%/*}

MIN_VIMRC="source $VIMDIR/vimrc"
MIN_BASHRC=". ~/.bash/bashrc"

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
        warn "$1 is not installed\n"
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

function setup_file_if_non_existent() {
    overwrite=true

    if [[ -r "$1" ]]; then
        if diff "$1" <(echo "$2") &>/dev/null; then
            info "Skipping default install for $1\n"
            overwrite=false
        else
            read -r -n 1 -p "Overwrite $1 with default? " answer
            echo

            if [[ $answer =~ ^[nN] ]]; then
                overwrite=false
            fi
        fi
    fi

    if $overwrite; then
        echo "$2" > "$1"
        new "Installed file $1 with default content\n"
    fi
}

function download_file() {
    if [[ -r "$1" ]]; then
        info "File $1 already installed\n"
        return
    fi
    new "Downloading $1... "
    curl -L "$2" > "$1" 2>/dev/null
    if (($? == 0)); then
        echo "done"
    else
        echo "failed"
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
        curl -SsLo $VIMDIR/autoload/pathogen.vim $PATHOGEN
        if (($? == 0)); then
            new "Installed pathogen.vim\n"
        else
            error "Failed to install pathogen.vim\n"
            exit 1
        fi
    fi
}

function install_vim_colorscheme() {
    mkdir -p $VIMDIR/colors

    if [[ -r $VIMDIR/colors/"$1.vim" ]]; then
        info "Color scheme $1 already installed\n"
        return
    else
        new "Installing color scheme $1... "
    fi

    TMPDIR="$(mktemp -d)"
    git clone "$2" "$TMPDIR" > /dev/null 2>&1
    if (($? == 0)); then
        echo "done"
        cp -a "$TMPDIR/colors/." $VIMDIR/colors/.
    else
        echo "failed"
    fi
    rm -rf "$TMPDIR"
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

function install_vim_docker_plugin() {
    # Ensure pathogen is installed
    install_pathogen

    local log="$(mktemp)"

    # Because the dockerfile plugin is inside the official docker git repo, we
    # need to clone it and extract just the part that we want.
    local dest_dir="$VIMDIR"/bundle/docker

    if [[ -d $dest_dir ]]; then
        info "Vim plugin docker already installed\n"
    else
        new "Installing vim plugin docker... "
        local temp="$(mktemp -d)"
        git clone "https://github.com/dotcloud/docker.git" "$temp" &> "$log"
        if (($? != 0)); then
            echo "failed"
            cat "$log"
        else
            command cp -r "$temp"/contrib/syntax/vim/ $dest_dir &>> "$log"
            if (($? == 0)); then
                echo "done"
            else
                echo "failed"
                cat "$log"
            fi
        fi

        rm -rf "$temp"
    fi

    rm -rf "$log"
}

function setup_rvm() {
    local log="$(mktemp)"

    if ! type -p rvm; then
        new "Installing RVM... "
        command curl -sSL https://get.rvm.io | bash -s stable &> "$log"

        if (($? != 0)); then
            echo "failed"
            cat "$log"
        else
            echo "done"
        fi
    fi

    rm -f "$log"
}

ensure_installed "ctags"
ensure_installed "ack"
ensure_installed "git"

setup_symlink ".bash" "$HOME/.bash"
setup_symlink ".git_template" "$HOME/.git_template"
setup_symlink ".tmux.conf" "$HOME/.tmux.conf"
setup_symlink ".vim" $VIMDIR
setup_symlink ".irbrc" "$HOME/.irbrc"

setup_file_if_non_existent "$HOME/.vimrc" "$MIN_VIMRC"
setup_file_if_non_existent "$HOME/.bashrc" "$MIN_BASHRC"

download_file "$HOME/.bash/git-prompt.sh" https://raw.github.com/git/git/master/contrib/completion/git-prompt.sh

touch "$HOME/.bash/paths.local"
touch "$HOME/.bash/exports.d/local"
touch "$HOME/.bash/aliases.d/local"

set_git_config 'init.templatedir' "$HOME/.git_template"
set_git_config 'alias.ctags' '!.git/hooks/ctags'
set_git_config 'alias.graph' 'log --all --graph --oneline --decorate=short'
set_git_config 'alias.lgraph' 'log --graph --oneline --decorate=short HEAD'
set_git_config 'alias.compress' 'repack -a -d --depth=250 --window=250'
set_git_config 'color.diff' 'auto'
set_git_config 'color.ui' 'auto'
set_git_config 'credential.helper' 'cache --timeout=3600'

install_vim_colorscheme "zenburn" https://github.com/jnurmine/Zenburn.git

install_vim_plugin "ctrlp.vim" https://github.com/kien/ctrlp.vim.git
install_vim_plugin "fugitive.vim" https://github.com/tpope/vim-fugitive.git
install_vim_plugin "syntastic" https://github.com/scrooloose/syntastic.git
install_vim_plugin "ultisnips" https://github.com/SirVer/ultisnips.git
install_vim_plugin "surround" https://github.com/tpope/vim-surround.git
install_vim_plugin "ack.vim" https://github.com/mileszs/ack.vim.git
install_vim_plugin "gundo.vim" https://github.com/sjl/gundo.vim.git
install_vim_plugin "vim-markdown" https://github.com/tpope/vim-markdown.git
install_vim_plugin "vim-haml" https://github.com/tpope/vim-haml.git
install_vim_plugin "riv.vim" https://github.com/Rykka/riv.vim.git
install_vim_docker_plugin

setup_rvm
