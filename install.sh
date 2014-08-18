#!/usr/bin/env bash

VIMDIR=~/.vim
PATHOGEN=https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim
BINDIR=~/.bin

ROOTDIR=$(readlink -f $0)
ROOTDIR=${ROOTDIR%/*}

MIN_VIMRC="source $VIMDIR/vimrc"
MIN_BASHRC=". ~/.bash/bashrc"
MIN_MUTTRC="source ~/.mutt/muttrc"

use_binary_ruby='no'

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

function usage() {
    cat <<EOT
Usage:
    $0 [-h | --help] [-b | --use-binary-ruby]

 -h | --help        Print this help and exit.

 -b, --use-binary-ruby
                    Only install binary rubies. This prevents RVM
                    from downloading and compiling any rubies. This
                    is useful for automation since it prevents the
                    installation from prompting for the user's
                    password if more packages are needed.
EOT
}

function parse_args() {
    while (($# > 0)); do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            -b | --use-binary-ruby)
                use_binary_ruby='yes'
                shift
                ;;
            *)
                echo -n "Unknown option '$1'. " >&2
                echo -n "Run with -h to see the help. " >&2
                echo "Exiting..." >&2
                exit 1
                break
                ;;
        esac
    done
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
            read -r -p "Overwrite $1 with default? " answer
            echo

            if ! [[ $answer =~ ^[yY] ]]; then
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

function install_tool() {
    local git_repo="$1"
    local git_repo_name="$(basename "$git_repo" .git)"
    local log="$(mktemp)"

    shift

    mkdir -p "$BINDIR"

    if [[ -d "$BINDIR/__tool_$git_repo_name" ]]; then
        info "Tools $@ already installed\n"
    else
        new "Installing tools $@... "
        git clone "$git_repo" "$BINDIR/__tool_$git_repo_name" &>"$log"
        if (($? == 0)); then
            while (($# > 0)); do
                ln -sf \
                    "$BINDIR/__tool_$git_repo_name/$1" \
                    "$BINDIR/$(basename "$1")"
                shift
            done

            echo "done"
        else
            echo "failed"
            cat "$log"
        fi
    fi

    rm -f "$log"
}

function setup_rvm() {
    local log="$(mktemp)"
    local result=0

    export PATH="~/.rvm/bin:$PATH"

    if type -p rvm > /dev/null; then
        info "RVM already installed\n"
    else
        new "Installing RVM... "

        rvm_installer="$(mktemp)"
        command curl -sSL https://get.rvm.io > "$rvm_installer" 2>>"$log"

        result=$?

        if ((result == 0)); then
            bash "$rvm_installer" \
                stable \
                --ignore-dotfiles \
                --autolibs=read-fail \
                &> "$log"

            result=$?
        fi

        if ((result == 0)); then
            echo "done"
        else
            echo "failed"
            cat "$log"
        fi
    fi

    # Set up the RVM environment properly.
    if ((result == 0)); then
        source ~/.rvm/scripts/rvm
        rvm rvmrc warning ignore all.rvmrcs
        rvm reload
    fi

    rm -f "$log"
}

function install_ruby() {
    if ! type -p rvm > /dev/null; then
        error "RVM not installed\n"
        return
    fi

    local version="$1"
    local extra_opts=""

    # Check to see if it's already installed.
    if rvm list | grep -q "$version"; then
        info "Ruby version $version already installed\n"
    else
        read -r -p "Install ruby version $version? " answer
        echo

        if ! [[ $answer =~ ^[yY] ]]; then
            return
        fi

        # Set the appropriate install options
        if [[ $use_binary_ruby == 'yes' ]]; then
            extra_opts="$extra_opts --binary"
        fi

        new "Installing ruby version $version...\n"
        rvm install "$version" $extra_opts

        if (($? != 0)); then
            echo "failed"
        else
            echo "done"
        fi
    fi

    rvm --default use "$version"
}

function install_gem() {
    local gem_name="$1"

    if ! (type -p rvm \
            && type -p gem \
            && ! rvm list | grep -q 'No rvm rubies installed') > /dev/null; then
        error "RVM gem tool is not in the PATH.\n"
        return
    fi

    if [[ "$(gem list "$gem_name" -i)" == true ]]; then
        info "Ruby gem $gem_name already installed\n"
        return
    fi

    local log="$(mktemp)"

    new "Installing ruby gem $gem_name... "
    gem install "$gem_name" &>"$log"

    if (($? == 0)); then
        echo "done"
    else
        echo "failed"
        cat "$log"
    fi

    rm -f "$log"
}

parse_args "$@"

ensure_installed "ctags"
ensure_installed "ack"
ensure_installed "git"

setup_symlink ".bash" "$HOME/.bash"
setup_symlink ".git_template" "$HOME/.git_template"
setup_symlink ".tmux.conf" "$HOME/.tmux.conf"
setup_symlink ".vim" $VIMDIR
setup_symlink ".irbrc" "$HOME/.irbrc"
setup_symlink ".rvmrc" "$HOME/.rvmrc"
setup_symlink ".colordiffrc" "$HOME/.colordiffrc"
setup_symlink ".mutt" "$HOME/.mutt"

setup_file_if_non_existent "$HOME/.vimrc" "$MIN_VIMRC"
setup_file_if_non_existent "$HOME/.bashrc" "$MIN_BASHRC"
setup_file_if_non_existent "$HOME/.muttrc" "$MIN_MUTTRC"

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

install_tool https://github.com/harelba/q "bin/q"
install_tool https://github.com/rkitover/vimpager "vimpager" "vimcat"

setup_rvm
install_ruby "ruby-2.1.2"
install_gem "bundler"
