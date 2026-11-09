#!/usr/bin/env bash
set -euo pipefail

version=8.21.2
ci_tools="${CI_TOOLS_DIR:-/opt/ci-tools}"
directory="$ci_tools/gitleaks/$version"

if [[ ! -x "$directory/gitleaks" ]]; then
  mkdir -p "$ci_tools/gitleaks" "$ci_tools/locks"
  exec 9>"$ci_tools/locks/gitleaks-$version.lock"
  flock 9
  if [[ ! -x "$directory/gitleaks" ]]; then
    tmp="$(mktemp -d "$ci_tools/gitleaks/.tmp-$version.XXXXXX")"
    trap 'rm -rf -- "$tmp"' EXIT
    archive="gitleaks_${version}_linux_x64.tar.gz"
    base="https://github.com/gitleaks/gitleaks/releases/download/v${version}"
    curl -fsSL --retry 3 -o "$tmp/$archive" "$base/$archive"
    curl -fsSL --retry 3 -o "$tmp/checksums.txt" "$base/gitleaks_${version}_checksums.txt"
    (cd "$tmp" && grep -E "^[[:xdigit:]]{64}  ${archive}\$" checksums.txt | sha256sum -c -)
    tar -xzf "$tmp/$archive" -C "$tmp" gitleaks
    chmod 0755 "$tmp/gitleaks"
    mkdir -p "$directory"
    mv "$tmp/gitleaks" "$directory/gitleaks"
  fi
  flock -u 9
fi

echo "$directory" >> "${GITHUB_PATH:?GITHUB_PATH must be set}"
"$directory/gitleaks" version
