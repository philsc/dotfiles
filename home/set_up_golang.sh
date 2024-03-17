#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

readonly URL="https://go.dev/dl/go1.21.0.linux-amd64.tar.gz"

TEMPDIR="$(mktemp -d)"
readonly TEMPDIR

pushd "${TEMPDIR}"

curl -LO "${URL}"

mkdir -p "${HOME}/.golang/"
tar -C "${HOME}/.golang/" -xaf *.tar.*

popd

rm -rf "${TEMPDIR}"

mkdir -p "${HOME}/.golang/path"
