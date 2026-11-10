#!/usr/bin/env bash
set -euo pipefail

version=8.30.1
expected_sha256=88f91962aa2f93ac6ab281d553b9e125f5197bbbce38f9f2437f7299c32e5509
ci_tools="${CI_TOOLS_DIR:-/opt/ci-tools}"
directory="$ci_tools/gitleaks/$version"
binary="$directory/gitleaks"

verified_binary() {
  [[ -x "$binary" ]] && printf '%s  %s\n' "$expected_sha256" "$binary" | sha256sum --check --status
}

if ! verified_binary; then
  mkdir -p "$ci_tools/gitleaks" "$ci_tools/locks"
  exec 9>"$ci_tools/locks/gitleaks-$version.lock"
  flock 9
  if ! verified_binary; then
    tmp="$(mktemp -d "$ci_tools/gitleaks/.tmp-$version.XXXXXX")"
    trap 'rm -rf -- "$tmp"' EXIT
    archive="gitleaks_${version}_linux_x64.tar.gz"
    base="https://github.com/gitleaks/gitleaks/releases/download/v${version}"
    curl -fsSL --retry 3 -o "$tmp/$archive" "$base/$archive"
    curl -fsSL --retry 3 -o "$tmp/checksums.txt" "$base/gitleaks_${version}_checksums.txt"
    (cd "$tmp" && grep -E "^[[:xdigit:]]{64}  ${archive}\$" checksums.txt | sha256sum -c -)
    tar -xzf "$tmp/$archive" -C "$tmp" gitleaks
    printf '%s  %s\n' "$expected_sha256" "$tmp/gitleaks" | sha256sum --check -
    chmod 0755 "$tmp/gitleaks"
    mkdir -p "$directory"
    mv -f "$tmp/gitleaks" "$binary"
  fi
  flock -u 9
fi

verified_binary || { echo '::error::cached Gitleaks binary failed its pinned SHA-256 check'; exit 1; }
echo "$directory" >> "${GITHUB_PATH:?GITHUB_PATH must be set}"
"$binary" version
