#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

readonly URL="https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz"

TEMPDIR="$(mktemp -d)"
readonly TEMPDIR

pushd "${TEMPDIR}"

curl -O "${URL}"

mkdir -p "${HOME}/.golang/"
tar -C "${HOME}/.golang/" -xaf *.tar.*

popd

rm -rf "${TEMPDIR}"

mkdir -p "${GOPATH}"
