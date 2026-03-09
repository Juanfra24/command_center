# Semantic Release Flow — Design

## Overview

Single GitHub Actions workflow that builds, validates commits, determines version bumps, updates `pubspec.yaml` + `CHANGELOG.md`, creates git tags, and publishes GitHub Releases with Windows build artifacts. Replaces the existing build-only `dart.yml` workflow.

## Workflow Trigger

- Push to `main` branch

## Pipeline Steps

1. **Commit lint** — validate all commit messages since last tag follow Conventional Commits format
2. **Build** — `flutter build windows --release`, upload artifact
3. **Analyze commits** — parse `feat:`, `fix:`, `BREAKING CHANGE` since last tag to determine bump type (major/minor/patch)
4. **Skip if no releasable commits** — `chore:`, `docs:`, `style:`, `refactor:`, `test:` alone don't trigger a release
5. **Bump version** — update `pubspec.yaml` version field
6. **Generate CHANGELOG** — prepend new section from commit messages, preserving existing content
7. **Commit + tag** — commit version bump + changelog, create `vX.Y.Z` tag
8. **GitHub Release** — create release with changelog as body, attach Windows build zip

## Commit → Bump Mapping

| Prefix | Bump | Changelog Section |
|--------|------|-------------------|
| `feat:` | minor | Features |
| `fix:` | patch | Bug Fixes |
| `perf:` | patch | Performance |
| `BREAKING CHANGE` | major | Breaking Changes |
| `chore:`, `docs:`, `style:`, `refactor:`, `test:` | none | — |

## Initial Setup

- Sync `pubspec.yaml` version to `0.4.0` to match CHANGELOG
- Tag current commit as `v0.4.0` as the baseline for future releases

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `.github/workflows/release.yml` | Create | Main release workflow (replaces `dart.yml`) |
| `.github/workflows/dart.yml` | Delete | Replaced by `release.yml` |
| `scripts/release/changelog.sh` | Create | Changelog generation from conventional commits |
| `scripts/release/version.sh` | Create | Version bump helper for pubspec.yaml |
| `pubspec.yaml` | Modify | Sync version to `0.4.0` |

## Design Decisions

- **GitHub Actions-only** — no Node.js dependencies (no semantic-release npm package)
- **Shell scripts for logic** — portable, no extra runtime needed
- **Single workflow** — build + release in one pipeline, avoids redundant CI runs
- **Conventional Commits enforced** — commit lint step rejects non-conforming messages
- **Auto-generated CHANGELOG** — replaces manual maintenance, existing content preserved
