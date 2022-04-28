#!/usr/bin/env bash

set -eu -o pipefail
shopt -s nullglob

psroot=$(dirname "$(dirname "$(realpath "$0")")")

if [[ "${CI:-}" && "$(echo $psroot/CHANGELOG.d/breaking_*)" ]]; then
  echo "Skipping package-set build due to unreleased breaking changes"
  exit 0
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export PATH="$tmpdir/node_modules/.bin:$PATH"
cd "$tmpdir"

if [[ "${CI:-}" ]]; then
  # Since this only runs on the Ubuntu build,
  # fix the ownership of the temporary directory
  # so `npm install` actually works
  chown root:root .
fi

echo ::group::Ensure Spago is available
npm i -g npm@8.8.0
which spago || npm install spago@0.20.8
echo ::endgroup::

echo ::group::Create dummy project
echo 'let upstream = https://github.com/purescript/package-sets/releases/download/XXX/packages.dhall in upstream' > packages.dhall
echo '{ name = "my-project", dependencies = [] : List Text, packages = ./packages.dhall, sources = [] : List Text }' > spago.dhall
spago upgrade-set
# Override the `metadata` package's version to match `purs` version
# so that `spago build` actually works
sed -i'' "\$c in upstream with metadata.version = \"v$(purs --version | { read v z && echo $v; })\"" packages.dhall
spago install $(spago ls packages | while read name z; do echo $name; done)
echo ::endgroup::

echo ::group::Compile package set
spago build
echo ::endgroup::

echo ::group::Document package set
spago docs --no-search
echo ::endgroup::
