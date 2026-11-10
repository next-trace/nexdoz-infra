#!/usr/bin/env bash
set -euo pipefail

version=0.11.0
archive_sha256=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
binary_sha256=4da528ddb3a4d1b7b24a59d4e16eb2f5fd960f4bd9a3708a15baddbdf1d5a55b
ci_tools="${CI_TOOLS_DIR:-/opt/ci-tools}"
root="$ci_tools/shellcheck"
directory="$root/$version"
binary="$directory/shellcheck"

verified_binary() {
  [[ -x "$binary" ]] && printf '%s  %s\n' "$binary_sha256" "$binary" | sha256sum --check --status
}

if ! verified_binary; then
  mkdir -p "$root" "$ci_tools/locks"
  exec 9>"$ci_tools/locks/shellcheck-$version.lock"
  flock 9
  if ! verified_binary; then
    tmp="$(mktemp -d "$root/.tmp-$version.XXXXXX")"
    trap 'rm -rf -- "$tmp"' EXIT
    archive="shellcheck-v${version}.linux.x86_64.tar.xz"
    url="https://github.com/koalaman/shellcheck/releases/download/v${version}/${archive}"
    curl -fsSL --retry 3 -o "$tmp/$archive" "$url"
    printf '%s  %s\n' "$archive_sha256" "$tmp/$archive" | sha256sum --check -
    tar -xJf "$tmp/$archive" -C "$tmp"
    extracted="$tmp/shellcheck-v${version}/shellcheck"
    printf '%s  %s\n' "$binary_sha256" "$extracted" | sha256sum --check -
    chmod 0755 "$extracted"
    mkdir -p "$directory"
    mv -f "$extracted" "$binary"
  fi
  flock -u 9
fi

verified_binary || { echo '::error::cached ShellCheck binary failed its pinned SHA-256 check'; exit 1; }
echo "$directory" >> "${GITHUB_PATH:?GITHUB_PATH must be set}"
"$binary" --version
