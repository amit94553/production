#!/usr/bin/env bash
# Build the dummy site into the given directory (default: out/).
# Stamps the commit so each build is a distinct artifact.
set -euo pipefail

out="${1:-out}"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo local)}"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

rm -rf "$out"
mkdir -p "$out"
sed -e "s/__COMMIT__/${commit}/" -e "s/__BUILT_AT__/${built_at}/" app/index.html > "$out/index.html"
printf '{"service":"sandbox-web","commit":"%s","built_at":"%s"}\n' "$commit" "$built_at" > "$out/version.json"

echo "Built $out/ for commit $commit"
