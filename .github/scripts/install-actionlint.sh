#!/usr/bin/env bash
set -euo pipefail

version=1.7.12
expected_sha256=c872d6db8c6bf83a8eaa704fc93999f027d55dffbc63b8a6abdccb47df5f4cd4
ci_tools="${CI_TOOLS_DIR:-/opt/ci-tools}"
root="$ci_tools/actionlint"
directory="$root/$version"
binary="$directory/actionlint"

verified_binary() {
  [[ -x "$binary" ]] && printf '%s  %s\n' "$expected_sha256" "$binary" | sha256sum --check --status
}

if ! verified_binary; then
  mkdir -p "$root" "$ci_tools/locks"
  exec 9>"$ci_tools/locks/actionlint-$version.lock"
  flock 9
  if ! verified_binary; then
    tmp="$(mktemp -d "$root/.tmp-$version.XXXXXX")"
    trap 'rm -rf -- "$tmp"' EXIT
    archive="actionlint_${version}_linux_amd64.tar.gz"
    base="https://github.com/rhysd/actionlint/releases/download/v${version}"
    curl -fsSL --retry 3 -o "$tmp/$archive" "$base/$archive"
    curl -fsSL --retry 3 -o "$tmp/checksums.txt" "$base/actionlint_${version}_checksums.txt"
    (cd "$tmp" && grep -E "^[[:xdigit:]]{64}  ${archive}\$" checksums.txt | sha256sum -c -)
    tar -xzf "$tmp/$archive" -C "$tmp" actionlint
    printf '%s  %s\n' "$expected_sha256" "$tmp/actionlint" | sha256sum --check -
    chmod 0755 "$tmp/actionlint"
    mkdir -p "$directory"
    mv -f "$tmp/actionlint" "$binary"
  fi
  flock -u 9
fi

verified_binary || { echo '::error::cached actionlint binary failed its pinned SHA-256 check'; exit 1; }
echo "$directory" >> "${GITHUB_PATH:?GITHUB_PATH must be set}"
"$binary" --version
