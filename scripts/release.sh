#!/bin/bash
# Builds, signs and publishes a GitHub release; installed copies of Ledge then update themselves.
# Usage: scripts/release.sh 1.2 "What changed"
# Needs: the GitHub CLI (`gh auth login` once) and a key from `swift scripts/update-key.swift generate`.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: scripts/release.sh <version> \"what changed\"}"
NOTES="${2:-Ledge $VERSION}"

scripts/build-app.sh "$VERSION"
swift scripts/update-key.swift sign build/Ledge.zip
gh release create "v$VERSION" build/Ledge.zip build/Ledge.zip.sig --title "Ledge $VERSION" --notes "$NOTES"
echo "Released v$VERSION"
