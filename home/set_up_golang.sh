#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

readonly GO_VERSION="1.27.1"

case "$(uname -m)" in
  x86_64)  readonly GO_ARCH="amd64" ;;
  aarch64) readonly GO_ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

readonly URL="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"

TEMPDIR="$(mktemp -d)"
readonly TEMPDIR

pushd "${TEMPDIR}"

curl -LO "${URL}"

mkdir -p "${HOME}/.golang/"
tar -C "${HOME}/.golang/" -xaf *.tar.*

popd

rm -rf "${TEMPDIR}"

mkdir -p "${HOME}/.golang/path"
