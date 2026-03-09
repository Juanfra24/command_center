# Semantic Release Flow — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automate versioning, changelog generation, and GitHub Releases from conventional commits via a single GitHub Actions workflow.

**Architecture:** A single `release.yml` workflow replaces the existing `dart.yml`. Two shell scripts (`scripts/release/version.sh` and `scripts/release/changelog.sh`) handle version bumping and changelog generation. The workflow validates commit messages, builds the Windows app, determines version bumps from conventional commits, updates `pubspec.yaml` + `CHANGELOG.md`, tags, and creates a GitHub Release with the build artifact.

**Tech Stack:** GitHub Actions, bash scripts, git tags, Conventional Commits

---

### Task 1: Sync version and create baseline tag

**Files:**
- Modify: `pubspec.yaml:7` (version line)

**Step 1: Update pubspec.yaml version to 0.4.0**

In `pubspec.yaml`, change:
```yaml
version: 0.2.1
```
to:
```yaml
version: 0.4.0
```

**Step 2: Commit and tag**

```bash
git add pubspec.yaml
git commit -m "chore: sync pubspec.yaml version to 0.4.0

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git tag -a v0.4.0 -m "v0.4.0 - baseline for semantic release"
```

---

### Task 2: Create the version bump script

**Files:**
- Create: `scripts/release/version.sh`

**Step 1: Create the script**

Create `scripts/release/version.sh`:

```bash
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
```

**Step 2: Make executable and commit**

```bash
chmod +x scripts/release/version.sh
git add scripts/release/version.sh
git commit -m "feat(release): add version bump script

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Create the changelog generation script

**Files:**
- Create: `scripts/release/changelog.sh`

**Step 1: Create the script**

Create `scripts/release/changelog.sh`:

```bash
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
```

**Step 2: Make executable and commit**

```bash
chmod +x scripts/release/changelog.sh
git add scripts/release/changelog.sh
git commit -m "feat(release): add changelog generation script

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Create the release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Delete: `.github/workflows/dart.yml`

**Step 1: Create the release workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Build & Release

on:
  push:
    branches:
      - main

permissions:
  contents: write

jobs:
  lint-commits:
    name: Validate Commit Messages
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get last tag
        id: last_tag
        run: |
          TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
          echo "tag=$TAG" >> "$GITHUB_OUTPUT"

      - name: Validate conventional commits
        run: |
          LAST_TAG="${{ steps.last_tag.outputs.tag }}"
          if [[ -z "$LAST_TAG" ]]; then
            echo "No tags found, skipping commit lint"
            exit 0
          fi

          INVALID=0
          while IFS= read -r msg; do
            if [[ -z "$msg" ]]; then continue; fi
            if ! echo "$msg" | grep -qE "^(feat|fix|chore|docs|style|refactor|perf|test|ci|build|revert)(\(.+\))?(!)?: .+"; then
              echo "❌ Invalid commit message: $msg"
              INVALID=$((INVALID + 1))
            fi
          done <<< "$(git log "${LAST_TAG}..HEAD" --pretty=format:"%s" --no-merges)"

          if [[ $INVALID -gt 0 ]]; then
            echo ""
            echo "Found $INVALID non-conventional commit(s)."
            echo "Format: <type>(<scope>): <description>"
            echo "Types: feat, fix, chore, docs, style, refactor, perf, test, ci, build, revert"
            exit 1
          fi
          echo "✅ All commits follow conventional format"

  build:
    name: Build Windows Application
    runs-on: windows-latest
    needs: lint-commits
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Install dependencies
        run: flutter pub get

      - name: Build Windows executable
        run: flutter build windows --release

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: windows-build
          path: build/windows/x64/runner/Release/**/*

  release:
    name: Create Release
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Determine version bump
        id: version
        run: |
          NEW_VERSION=$(bash scripts/release/version.sh --dry-run 2>/dev/null) || true
          if [[ -z "$NEW_VERSION" ]]; then
            echo "skip=true" >> "$GITHUB_OUTPUT"
            echo "No releasable commits — skipping release"
          else
            echo "skip=false" >> "$GITHUB_OUTPUT"
            echo "new_version=$NEW_VERSION" >> "$GITHUB_OUTPUT"
            echo "Will release v${NEW_VERSION}"
          fi

      - name: Bump version in pubspec.yaml
        if: steps.version.outputs.skip == 'false'
        run: bash scripts/release/version.sh

      - name: Generate changelog
        if: steps.version.outputs.skip == 'false'
        id: changelog
        run: |
          BODY=$(bash scripts/release/changelog.sh "${{ steps.version.outputs.new_version }}")
          # Write to file for the release body (handles multiline)
          echo "$BODY" > /tmp/release_body.md

      - name: Commit version bump and changelog
        if: steps.version.outputs.skip == 'false'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add pubspec.yaml CHANGELOG.md
          git commit -m "chore(release): v${{ steps.version.outputs.new_version }}"
          git tag -a "v${{ steps.version.outputs.new_version }}" -m "v${{ steps.version.outputs.new_version }}"
          git push origin main --follow-tags

      - name: Download build artifact
        if: steps.version.outputs.skip == 'false'
        uses: actions/download-artifact@v4
        with:
          name: windows-build
          path: release-artifact/

      - name: Zip build artifact
        if: steps.version.outputs.skip == 'false'
        run: |
          cd release-artifact
          zip -r "../command-center-v${{ steps.version.outputs.new_version }}-windows.zip" .

      - name: Create GitHub Release
        if: steps.version.outputs.skip == 'false'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: "v${{ steps.version.outputs.new_version }}"
          name: "v${{ steps.version.outputs.new_version }}"
          body_path: /tmp/release_body.md
          files: "command-center-v${{ steps.version.outputs.new_version }}-windows.zip"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Step 2: Delete old workflow and commit**

```bash
rm .github/workflows/dart.yml
git add .github/workflows/release.yml
git rm .github/workflows/dart.yml
git commit -m "feat(ci): add semantic release workflow, replace build-only workflow

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Test scripts locally

**Step 1: Test version bump (dry run)**

```bash
cd /c/Users/Juanfra/projects/command_center
bash scripts/release/version.sh --dry-run
```

Expected: prints a version like `0.5.0` (minor bump since there are `feat:` commits since tag) and exits 0. `pubspec.yaml` should remain unchanged.

**Step 2: Test changelog generation (dry run)**

```bash
bash scripts/release/changelog.sh "0.5.0"
```

Expected: modifies `CHANGELOG.md` with a new `## [0.5.0]` section containing features parsed from recent commits. Verify the output looks correct, then revert:

```bash
git checkout -- CHANGELOG.md
```

**Step 3: Commit test verification**

No commit needed — this is validation only.

---

### Task 6: Update documentation

**Files:**
- Modify: `CLAUDE.md` (add release workflow section)
- Modify: `README.md` (add release info)

**Step 1: Add release section to CLAUDE.md**

After the "Build & Run" section in `CLAUDE.md`, add:

```markdown
## Release Flow

Automated semantic releases via GitHub Actions (`.github/workflows/release.yml`):

1. Push to `main` triggers: commit lint → build → release
2. Commits are analyzed for `feat:` (minor), `fix:`/`perf:` (patch), `BREAKING CHANGE` (major)
3. If releasable commits exist: bumps `pubspec.yaml`, updates `CHANGELOG.md`, tags, creates GitHub Release with Windows zip
4. Non-releasable commits (`chore:`, `docs:`, `style:`, `refactor:`, `test:`) only build — no release

**Commit message format (enforced):**
```
<type>(<scope>): <description>
```
Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `ci`, `build`, `revert`
```

**Step 2: Add release info to README.md**

After the "Development" section in `README.md`, add:

```markdown
## Releases

Releases are automated via GitHub Actions using conventional commits:

- `feat:` commits trigger a **minor** version bump
- `fix:` / `perf:` commits trigger a **patch** version bump
- `BREAKING CHANGE` triggers a **major** version bump
- Other commit types (`chore:`, `docs:`, etc.) do not trigger a release

Each release auto-generates changelog entries and publishes a GitHub Release with the Windows build.
```

**Step 3: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: add semantic release documentation

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```
