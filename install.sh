#!/usr/bin/env bash

VIMDIR=~/.vim
BINDIR=~/.bin

ROOTDIR=$(readlink -f $0)
ROOTDIR=${ROOTDIR%/*}

MIN_VIMRC="source $VIMDIR/vimrc"
MIN_BASHRC=". ~/.bash/bashrc"
MIN_MUTTRC="source ~/.mutt/muttrc"

install_ruby='no'
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

 -r | --ruby        Install ruby via RVM.

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
            -r | --ruby)
                install_ruby='yes'
                shift
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
        return 1
    fi

    return 0
}

function setup_symlink() {
    if [[ -L "$2" ]]; then
        info "Symlink $2 already installed\n"
    elif [[ -e "$2" ]]; then
        warn "$2 already exists, but is not a symlink\n"
    else
        new "Installing symlink $2\n"
        ln -s "$1" "$2"
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
    local file="$1"
    local output=""

    if [[ -r "$file" ]]; then
        info "File $file already installed\n"
        return
    fi
    new "Downloading $file... "
    output="$(curl -L "$2" 2>&1 > "$file")"
    if (($? == 0)); then
        echo "done"
    else
        echo "failed"
        rm -f "$file"
        echo "$output"
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

mkdir -p "$HOME/.bin"

setup_symlink "$ROOTDIR/.bash" "$HOME/.bash"
setup_symlink "$ROOTDIR/.git_template" "$HOME/.git_template"
setup_symlink "$ROOTDIR/.tmux.conf" "$HOME/.tmux.conf"
setup_symlink "$ROOTDIR/.vim" $VIMDIR
setup_symlink "$ROOTDIR/.irbrc" "$HOME/.irbrc"
setup_symlink "$ROOTDIR/.rvmrc" "$HOME/.rvmrc"
setup_symlink "$ROOTDIR/.colordiffrc" "$HOME/.colordiffrc"
setup_symlink "$ROOTDIR/.mutt" "$HOME/.mutt"
setup_symlink "$ROOTDIR/tools/q/bin/q" "$HOME/.bin/q"
setup_symlink "$ROOTDIR/tools/vimpager/vimcat" "$HOME/.bin/vimcat"
setup_symlink "$ROOTDIR/tools/vimpager/vimpager" "$HOME/.bin/vimpager"
setup_symlink "$ROOTDIR/awesome" "$HOME/.config/awesome"
setup_symlink "$ROOTDIR/.Xresources" "$HOME/.Xresources"
setup_symlink "$ROOTDIR/.xprofile" "$HOME/.xprofile"
setup_symlink "$ROOTDIR/.xinitrc" "$HOME/.xinitrc"
setup_symlink "$ROOTDIR/.gtkrc-2.0" "$HOME/.gtkrc-2.0"
setup_symlink "$ROOTDIR/.fonts" "$HOME/.fonts"
setup_symlink "$ROOTDIR/fontconfig" "$HOME/.config/fontconfig"
setup_symlink "$HOME/.config/fontconfig/fonts.conf" "$HOME/.fonts.conf"

if ensure_installed "eatmydata"; then
    setup_symlink "$(type -p eatmydata)" "$HOME/.bin/apt-get"
    setup_symlink "$(type -p eatmydata)" "$HOME/.bin/aptitude"
    setup_symlink "$(type -p eatmydata)" "$HOME/.bin/dpkg"
fi

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

if [[ $install_ruby == yes ]]; then
    setup_rvm
    install_ruby "ruby-2.1.2"
    install_gem "bundler"
fi
