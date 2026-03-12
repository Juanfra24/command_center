# Repo Improvements — Design Spec

## Status: APPROVED

## Context

After completing a 22-bug-fix audit across all 5 core flows, a thorough codebase exploration identified 11 categories of improvement opportunities. This spec defines a 5-phase roadmap to address them all, sequenced to maximize stability at each step.

## Approach

**CI First, Then Interleaved (Approach C):** Harden CI immediately for a safety net, standardize error handling before decomposing files so new code follows the pattern from the start, write tests against the final clean architecture, then polish docs and logging last. Each phase is its own PR to `dev`.

---

## Phase 1: CI Hardening

### Goal
Catch regressions automatically before they reach `dev` or `main`.

### Changes

**`.github/workflows/release.yml`** — Add three steps before the build step:

1. **`dart format --set-exit-if-changed .`** — Enforces consistent formatting. Any unformatted code fails the build.
2. **`flutter analyze`** — Catches static analysis errors. The 12 pre-existing infos (`avoid_print`, `use_build_context_synchronously`, `deprecated_member_use`) must be fixed or suppressed first.
3. **`flutter test`** — Runs unit tests. Initially a no-op (no tests exist yet), but wired up so Phase 4 tests run automatically.

**`scripts/hooks/pre-commit`** — Local pre-commit hook running `dart format` so formatting issues are caught before push. Documented in SETUP.md.

**CI job placement:** Add a new `lint` job on Ubuntu (fast, cheap) that runs `dart format` and `flutter analyze` in parallel with the existing Windows `build` job. The `build` job gains `needs: [lint]` so it only runs if linting passes. `flutter test` runs inside the `lint` job (same Ubuntu runner).

### Files affected
- `.github/workflows/release.yml`
- `scripts/hooks/pre-commit` (new)
- 4 files with Dart `print()` calls → replace with `logger` (`random_skills.dart`, `native_commands_service.dart`, `process_model.dart`, `status_controller.dart`). Note: `python_setup_service.dart` has `print()` inside Python command strings — those are not Dart calls and should not be changed.
- `core/helper/logger.dart` → fix deprecated `printTime` usage
- Files with `use_build_context_synchronously` infos → add `mounted` guards

---

## Phase 2: Error Handling Contract

### Goal
Replace ad-hoc error handling with a single consistent pattern across all layers.

### The Pattern

**`Result<T>` sealed class** (new file: `lib/core/resource/result.dart`):
```dart
sealed class Result<T> {
  factory Result.success(T data) = Success<T>;
  factory Result.failure(String message, [Object? error]) = Failure<T>;
}

class Success<T> implements Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> implements Result<T> {
  final String message;
  final Object? error;
  const Failure(this.message, [this.error]);
}
```

### Layer responsibilities

| Layer | Error contract |
|-------|---------------|
| **API Clients** | Throw on HTTP/parse failure. No error observables. |
| **Services** | Catch exceptions from API clients/repos, return `Result<T>`. No error observables. |
| **Controllers** | Unwrap `Result`, set UI observables (`lastError`, `isLoading`), call `logger`. Only layer that touches observables. |
| **Repositories** | Wrap Drift calls in try-catch, return `Result<T>` instead of throwing. |

### Controller pattern-matching idiom

Controllers consume `Result<T>` via exhaustive `switch`:

```dart
final result = await _webshareService.testAndConnect(apiKey);
switch (result) {
  case Success(:final data):
    lastError.value = null;
    slots.assignAll(data);
  case Failure(:final message):
    lastError.value = message;
    logger.e(message);
}
```

### Migration of existing return types

Several services already use ad-hoc result types that will be replaced by `Result<T>`:

| Current pattern | Files | Migration |
|----------------|-------|-----------|
| `({bool success, String? error})` | `WebshareService`, `ProxyReplacementService`, `ProxyReplacementController` | Replace with `Result<void>` or `Result<T>` as appropriate |
| `AutomationResult` class | `AutomationService`, `ResultParser` | Keep as-is — domain-specific result with extra fields (`data`, `status`). Not a candidate for `Result<T>`. |
| `IpqsResult` class | `IpqsService`, `IpqsApiClient` | Keep as-is — domain-specific result carrying scoring data. Not a candidate for `Result<T>`. |

Only the `({bool success, String? error})` record pattern is replaced. Domain-specific result classes (`AutomationResult`, `IpqsResult`) stay because they carry meaningful domain data beyond success/failure.

### Files affected
- New: `lib/core/resource/result.dart`
- Services: `WebshareService`, `IpqsService`, `AutomationService`, `AppConfigService`, `OnboardingService`
- Controllers: `ProxyController`, `StatusController`, `ProxyScoringController`, `ProxyReplacementController`
- Repositories: `AccountRepositoryImpl`, `ProxyRepositoryImpl`, `ConfigRepositoryImpl`

---

## Phase 3: Architecture Decomposition

### Goal
Bring all files within the CLAUDE.md size ceilings by splitting oversized files into sections/components.

### Screens (max 150 lines)

| File | Current | Action |
|------|---------|--------|
| `main_menu_screen.dart` | 405 | Extract 3 cards (System Overview, Characters Status, Recent Activity) into section files. Helpers like `_buildStatCard`, `_buildCharacterStatusCard`, and count logic move with their sections. |
| `proxy_screen.dart` | 380 | Extract toolbar actions, scoring panel, detail/list layout into sections |

### Components (max 200 lines)

| File | Current | Action |
|------|---------|--------|
| `ip_score_analysis.dart` | 359 | Split into `score_summary.dart`, `score_detail_table.dart`, `score_flags.dart` |
| `proxy_slot_card.dart` | 293 | Extract card header, card body, card actions |
| `slot_header.dart` | 237 | Contains two classes: `SlotHeader` (192 lines) and `CurrentIpCard` (44 lines). Extract `CurrentIpCard` into its own file `current_ip_card.dart`. |
| `about_card.dart` | 235 | Extract version info, links section |

### Services (max 250 lines)

| File | Current | Action |
|------|---------|--------|
| `python_setup_service.dart` | 294 | Extract dependency checker logic into helper |
| `webshare_service.dart` | 293 | Move remaining HTTP logic to `webshare_api_client.dart` |

### Not decomposed
- `proxy_ip_address_model.dart` (301 lines) — inherently verbose due to many fields. Leave as-is.
- `proxy_controller.dart` (309 lines) — only 3% over, tolerable after Phase 2 cleanup.

All decompositions follow the existing pattern: screen → sections → components → dialogs. No new architectural patterns introduced.

---

## Phase 4: Tests

### Goal
Build a meaningful test safety net for the cleaned-up codebase.

### Setup
- Create `test/` directory mirroring `lib/` structure
- Add `mocktail` to `dev_dependencies` in `pubspec.yaml`
- Create test helpers: mock factories for `DatabaseService`, `WebshareService`, `IpqsService`

### Unit tests (highest value)
- **Result type** — success/failure construction, pattern matching
- **Services** — `AutomationService`, `WebshareService`, `IpqsService`, `AppConfigService`, `ProxySyncService`. Mock API clients/repos, test business logic.
- **Repositories** — `AccountRepositoryImpl`, `ProxyRepositoryImpl`. In-memory Drift database, test CRUD + edge cases (corrupted JSON, soft delete).
- **Controllers** — `ProxyController`, `StatusController`, `ProxyScoringController`. Mock services, test state transitions.

### Widget tests (medium value)
- Critical dialogs: `WebshareConfigDialog`, `AddSlotDialog` — test validation, error states
- Key components: `IpHistoryList`, `ProxySlotCard` — test rendering with edge case data

### Not included (diminishing returns)
- Integration tests (require Windows runner)
- Golden tests (high maintenance for desktop app)
- Python script tests (separate concern, could be follow-up)

### Target
Cover all services and repositories. No coverage threshold enforced — the goal is a meaningful safety net, not a number.

---

## Phase 5: Docs & Polish

### Documentation
- **`scripts/README.md`** — How to run Python scripts manually, dependency setup, expected output format, debugging tips
- **`docs/DATABASE.md`** — ERD of the 5 tables, migration strategy, how to add new tables/columns, backup location
- **Enhance `SETUP.md`** — Development environment setup, how to run locally, how to run tests

### Logging improvements
- Add optional file logging to `core/helper/logger.dart` (write to `getApplicationDocumentsDirectory()/logs/`)
- Add log rotation (max 5MB per file, keep 3 files)
- Replace remaining `print()` calls with `logger` (if any survived Phase 1)

### Minor polish
- Mask account passwords in `ValidationStatusIndicator` result display (show `••••••` instead of plaintext)
- Add cascade delete for Characters → Accounts foreign key in Drift schema (requires schema version bump to v3). This requires updating `MigrationStrategy` in `AppDatabase` with a `from2To3` migration step and regenerating with `build_runner`.
- Investigate `fluent_ui` pin — document why 4.14+ breaks, or upgrade if fixed

---

## Execution Order

Each phase is its own PR to `dev`:

1. **Phase 1: CI Hardening** — ~2 hours. Immediate safety net.
2. **Phase 2: Error Handling** — Largest phase. Define `Result<T>`, update all services/controllers/repos.
3. **Phase 3: Architecture** — Split 8 oversized files. Follow new error patterns.
4. **Phase 4: Tests** — Write tests against clean, final code.
5. **Phase 5: Docs & Polish** — Documentation, logging, minor fixes.

## Key Files

| Phase | Key Files |
|-------|-----------|
| 1 | `.github/workflows/release.yml`, `core/helper/logger.dart`, 4 files with `print()` |
| 2 | `core/resource/result.dart` (new), 6 services, 4 controllers, 3 repositories |
| 3 | `main_menu_screen.dart`, `proxy_screen.dart`, 4 components, 2 services |
| 4 | `test/` directory (new), `pubspec.yaml`, mock factories |
| 5 | `scripts/README.md`, `docs/DATABASE.md`, `SETUP.md`, `logger.dart`, `validation_status_indicator.dart` |
