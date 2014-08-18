#!/usr/bin/env bash

readonly SCRIPTDIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

function update_vim_docker_plugin() {
    local log="$(mktemp)"

    # Because the dockerfile plugin is inside the official docker git repo, we
    # need to clone it and extract just the part that we want.
    printf "Updating vim plugin docker... "
    local temp="$(mktemp -d)"
    git clone "https://github.com/dotcloud/docker.git" "$temp" &> "$log"
    if (($? != 0)); then
        echo "failed"
        cat "$log"
    else
        command cp -rf "$temp"/contrib/syntax/vim/. "${SCRIPTDIR}/." &>> "$log"
        if (($? == 0)); then
            echo "done"
        else
            echo "failed"
            cat "$log"
        fi
    fi

    rm -rf "$temp"
    rm -rf "$log"
}

update_vim_docker_plugin
