#!/bin/bash
# version.sh — Analyze conventional commits since last tag and bump version in pubspec.yaml
#
# Usage: ./scripts/release/version.sh [--dry-run]
# Output: Prints the new version to stdout. With --dry-run, does not modify pubspec.yaml.
#
# Exit codes:
#   0 — version bumped (or would be bumped with --dry-run)
#   1 — no releasable commits found

set -euo pipefail

PUBSPEC="pubspec.yaml"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

# Get the latest tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [[ -z "$LAST_TAG" ]]; then
  echo "ERROR: No existing tags found. Create a baseline tag first." >&2
  exit 1
fi

# Get commits since last tag
if [[ -n "$LAST_TAG" ]]; then
  COMMITS=$(git log "${LAST_TAG}..HEAD" --pretty=format:"%s" --no-merges)
else
  COMMITS=$(git log --pretty=format:"%s" --no-merges)
fi

if [[ -z "$COMMITS" ]]; then
  echo "No commits since $LAST_TAG" >&2
  exit 1
fi

# Determine bump type
BUMP="none"

while IFS= read -r msg; do
  # Check for breaking changes
  if echo "$msg" | grep -qiE "^[a-z]+(\(.+\))?!:|BREAKING CHANGE"; then
    BUMP="major"
    break
  fi
  # Check for features
  if echo "$msg" | grep -qE "^feat(\(.+\))?:"; then
    if [[ "$BUMP" != "major" ]]; then
      BUMP="minor"
    fi
  fi
  # Check for fixes and perf
  if echo "$msg" | grep -qE "^(fix|perf)(\(.+\))?:"; then
    if [[ "$BUMP" == "none" ]]; then
      BUMP="patch"
    fi
  fi
done <<< "$COMMITS"

if [[ "$BUMP" == "none" ]]; then
  echo "No releasable commits (feat/fix/perf) since $LAST_TAG" >&2
  exit 1
fi

# Read current version from pubspec.yaml
CURRENT=$(grep -E "^version:" "$PUBSPEC" | head -1 | sed 's/version: *//')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

# Strip any build metadata (e.g., +1)
PATCH=$(echo "$PATCH" | sed 's/+.*//')

case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

if [[ "$DRY_RUN" == false ]]; then
  sed -i "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"
fi

echo "$NEW_VERSION"
