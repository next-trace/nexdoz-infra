#!/usr/bin/env bash
set -euo pipefail

version=1.7.12
ci_tools="${CI_TOOLS_DIR:-/opt/ci-tools}"
root="$ci_tools/actionlint"
directory="$root/$version"

if [[ ! -x "$directory/actionlint" ]]; then
  mkdir -p "$root" "$ci_tools/locks"
  exec 9>"$ci_tools/locks/actionlint-$version.lock"
  flock 9
  if [[ ! -x "$directory/actionlint" ]]; then
    tmp="$(mktemp -d "$root/.tmp-$version.XXXXXX")"
    trap 'rm -rf -- "$tmp"' EXIT
    archive="actionlint_${version}_linux_amd64.tar.gz"
    base="https://github.com/rhysd/actionlint/releases/download/v${version}"
    curl -fsSL --retry 3 -o "$tmp/$archive" "$base/$archive"
    curl -fsSL --retry 3 -o "$tmp/checksums.txt" "$base/actionlint_${version}_checksums.txt"
    (cd "$tmp" && grep -E "^[[:xdigit:]]{64}  ${archive}\$" checksums.txt | sha256sum -c -)
    tar -xzf "$tmp/$archive" -C "$tmp" actionlint
    chmod 0755 "$tmp/actionlint"
    mkdir -p "$directory"
    mv "$tmp/actionlint" "$directory/actionlint"
  fi
  flock -u 9
fi

echo "$directory" >> "${GITHUB_PATH:?GITHUB_PATH must be set}"
"$directory/actionlint" --version
