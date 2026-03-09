#!/bin/bash
# changelog.sh — Generate a changelog section from conventional commits since last tag
#
# Usage: ./scripts/release/changelog.sh <version>
# Output: Prepends a new section to CHANGELOG.md under the [Unreleased] header.
#
# If no CHANGELOG.md exists, creates one. Preserves existing content.

set -euo pipefail

NEW_VERSION="${1:?Usage: changelog.sh <version>}"
CHANGELOG="CHANGELOG.md"
DATE=$(date +%Y-%m-%d)

# Get the latest tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# Get commits since last tag
if [[ -n "$LAST_TAG" ]]; then
  COMMITS=$(git log "${LAST_TAG}..HEAD" --pretty=format:"%s" --no-merges)
else
  COMMITS=$(git log --pretty=format:"%s" --no-merges)
fi

# Categorize commits
FEATURES=""
FIXES=""
PERFORMANCE=""
BREAKING=""

while IFS= read -r msg; do
  # Clean the message: remove type prefix, extract scope and description
  if echo "$msg" | grep -qE "^[a-z]+(\(.+\))?!:"; then
    desc=$(echo "$msg" | sed 's/^[a-z]*\(([^)]*)\)\?!: *//')
    scope=$(echo "$msg" | sed -n 's/^[a-z]*(\([^)]*\))!:.*/\1/p')
    if [[ -n "$scope" ]]; then
      BREAKING="${BREAKING}- ${desc} (${scope})\n"
    else
      BREAKING="${BREAKING}- ${desc}\n"
    fi
    continue
  fi

  if echo "$msg" | grep -qE "^feat(\(.+\))?:"; then
    desc=$(echo "$msg" | sed 's/^feat\(([^)]*)\)\?: *//')
    scope=$(echo "$msg" | sed -n 's/^feat(\([^)]*\)):.*/\1/p')
    if [[ -n "$scope" ]]; then
      FEATURES="${FEATURES}- ${desc} (${scope})\n"
    else
      FEATURES="${FEATURES}- ${desc}\n"
    fi
  fi

  if echo "$msg" | grep -qE "^fix(\(.+\))?:"; then
    desc=$(echo "$msg" | sed 's/^fix\(([^)]*)\)\?: *//')
    scope=$(echo "$msg" | sed -n 's/^fix(\([^)]*\)):.*/\1/p')
    if [[ -n "$scope" ]]; then
      FIXES="${FIXES}- ${desc} (${scope})\n"
    else
      FIXES="${FIXES}- ${desc}\n"
    fi
  fi

  if echo "$msg" | grep -qE "^perf(\(.+\))?:"; then
    desc=$(echo "$msg" | sed 's/^perf\(([^)]*)\)\?: *//')
    scope=$(echo "$msg" | sed -n 's/^perf(\([^)]*\)):.*/\1/p')
    if [[ -n "$scope" ]]; then
      PERFORMANCE="${PERFORMANCE}- ${desc} (${scope})\n"
    else
      PERFORMANCE="${PERFORMANCE}- ${desc}\n"
    fi
  fi
done <<< "$COMMITS"

# Build the new section
SECTION="## [${NEW_VERSION}] - ${DATE}\n"

if [[ -n "$BREAKING" ]]; then
  SECTION="${SECTION}\n### Breaking Changes\n\n${BREAKING}"
fi
if [[ -n "$FEATURES" ]]; then
  SECTION="${SECTION}\n### Features\n\n${FEATURES}"
fi
if [[ -n "$FIXES" ]]; then
  SECTION="${SECTION}\n### Bug Fixes\n\n${FIXES}"
fi
if [[ -n "$PERFORMANCE" ]]; then
  SECTION="${SECTION}\n### Performance\n\n${PERFORMANCE}"
fi

# Insert into CHANGELOG.md
if [[ ! -f "$CHANGELOG" ]]; then
  printf "# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n## [Unreleased]\n\n%b\n" "$SECTION" > "$CHANGELOG"
else
  # Replace [Unreleased] section content: insert new version after [Unreleased] header
  # Strategy: find the [Unreleased] line, clear everything between it and the next ## header,
  # then insert the new version section
  TEMP=$(mktemp)
  awk -v section="$(printf '%b' "$SECTION")" '
    /^## \[Unreleased\]/ {
      print $0
      print ""
      print section
      found_unreleased = 1
      skip = 1
      next
    }
    /^## \[/ && found_unreleased && skip {
      skip = 0
    }
    !skip { print }
  ' "$CHANGELOG" > "$TEMP"
  mv "$TEMP" "$CHANGELOG"
fi

# Also output the section for use as GitHub Release body
printf '%b' "$SECTION" | sed 's/^## .*//'
