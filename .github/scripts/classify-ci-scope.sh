#!/usr/bin/env bash
set -euo pipefail

full_validation() {
  printf 'full\n'
  exit 0
}

[[ $# -eq 2 ]] || full_validation
base_sha="$1"
head_sha="$2"
git rev-parse --verify "${base_sha}^{commit}" >/dev/null 2>&1 || full_validation
git rev-parse --verify "${head_sha}^{commit}" >/dev/null 2>&1 || full_validation

changed_paths="$(mktemp)"
trap 'rm -f -- "$changed_paths"' EXIT
git diff --no-ext-diff --name-only -z "$base_sha" "$head_sha" > "$changed_paths" || full_validation
[[ -s "$changed_paths" ]] || full_validation

scope=docs
while IFS= read -r -d '' path; do
  case "$path" in
    .github/scripts/*|.github/workflows/ci.yml|scripts/test-ci-scope.sh|docker/caddy/Dockerfile|docker/postgres/Dockerfile)
      scope=full
      ;;
    .github/*|.gitleaks.toml|scripts/ci-*)
      [[ "$scope" == full ]] || scope=ci
      ;;
    .plan/*|.codex/*|.claude/*|.agents/*|docs/*|Docs/*|design/*|designs/*|strategy/*|architecture/*|diagrams/*|images/*|\
    README*|*/README*|HANDOFF.md|SECURITY.md|LICENSE*|*/LICENSE*|NOTICE*|*/NOTICE*|CHANGELOG*|*/CHANGELOG*|\
    *.md|*.mdx|*.adoc|*.txt|*.drawio|*.mmd|*.puml|*.svg|*.png|*.ico|*.webp|*.jpg|*.jpeg|*.gif|*.woff|*.woff2|*.ttf|*.otf)
      ;;
    *)
      scope=full
      break
      ;;
  esac
done < "$changed_paths"

printf '%s\n' "$scope"
