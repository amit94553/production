#!/usr/bin/env bash
# Dummy deploy. Nothing leaves the runner: it "releases" the built site into
# deployed/ and writes a record to the job summary. Swap this for a real
# deploy command once the gate behaves as expected.
set -euo pipefail

src="${1:-out}"
release="deployed/$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$release"
cp -R "$src"/. "$release"/

echo "Deployed sandbox-web to ${ATLASENT_ENV:-production}"
echo "  release:  $release"
echo "  digest:   ${ARTIFACT_DIGEST:-unknown}"
cat "$release/version.json"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Deployed sandbox-web"
    echo
    echo "| Field | Value |"
    echo "| --- | --- |"
    echo "| Environment | ${ATLASENT_ENV:-production} |"
    echo "| Artifact digest | \`${ARTIFACT_DIGEST:-unknown}\` |"
    echo "| Commit | \`${GITHUB_SHA:-local}\` |"
  } >> "$GITHUB_STEP_SUMMARY"
fi
