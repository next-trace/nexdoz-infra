#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
classifier="$repo_root/.github/scripts/classify-ci-scope.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir "$tmp/repo"
cd "$tmp/repo"
git init -q
git config user.name 'CI scope test'
git config user.email 'ci-scope-test@example.invalid'
printf 'base\n' > baseline
git add baseline
git commit -qm baseline
base="$(git rev-parse HEAD)"

expect_scope() {
  local expected="$1"; shift
  git reset --hard -q "$base"
  git clean -fdq
  local path
  for path in "$@"; do
    mkdir -p "$(dirname "$path")"
    printf 'fixture\n' > "$path"
    git add -- "$path"
  done
  git commit -qm fixture
  local head actual
  head="$(git rev-parse HEAD)"
  actual="$(bash "$classifier" "$base" "$head")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected scope %s for [%s], got %s\n' "$expected" "$*" "$actual" >&2
    exit 1
  fi
}

expect_scope docs README.md
expect_scope docs 'docs/design image.png'
expect_scope docs architecture/overview.drawio
expect_scope ci .github/workflows/deploy-prod.yml
expect_scope full .github/workflows/ci.yml
expect_scope ci .github/dependabot.yml
expect_scope full .github/scripts/install-actionlint.sh
expect_scope full .github/scripts/install-gitleaks.sh
expect_scope full .github/scripts/run-validation-parallel.sh
expect_scope full .github/scripts/classify-ci-scope.sh
expect_scope full scripts/test-ci-scope.sh
expect_scope ci .gitleaks.toml
expect_scope full docker-compose.prod.yml
expect_scope full Caddyfile
expect_scope full .env.dist
expect_scope full scripts/deploy.sh
expect_scope full .trivyignore
expect_scope full README.md .github/workflows/ci.yml
expect_scope full README.md scripts/deploy.sh

if [[ "$(bash "$classifier" invalid-ref "$base")" != full ]]; then
  echo 'Invalid revisions must fail closed to full validation.' >&2
  exit 1
fi
if [[ "$(bash "$classifier" "$base" "$base")" != full ]]; then
  echo 'Empty diffs must fail closed to full validation.' >&2
  exit 1
fi

echo 'CI scope classifier tests passed.'
