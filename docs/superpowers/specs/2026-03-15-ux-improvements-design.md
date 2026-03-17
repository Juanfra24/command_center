# UX Improvements — Unified Design Pass

**Date:** 2026-03-15
**Status:** Draft
**Scope:** Accounts Table, Proxy Detail Pane, Dashboard, Status Feedback, Shared UI Patterns

## Overview

A cohesive UX improvement pass across 5 areas of the Command Center app. Introduces shared UI patterns (toast notifications, loading states, multi-select, collapsible sections) and applies them consistently across all screens.

### Goals

- Reduce information density without losing data (Accounts table, Proxy detail)
- Make the Dashboard a real command center with live bot status and proxy health
- Add search/filter to the Accounts table
- Introduce multi-select with bulk start/stop for characters
- Add default scripts per character so "Start All" works without dialogs
- Provide consistent status feedback (inline spinners + toast notifications)
- Display all relevant IPQS data accurately (booleans as booleans, add missing fields)

### Non-Goals

- No new navigation tabs or screens
- No changes to Settings, Music, Notifications, or DevTools screens
- No changes to the onboarding flow
- No changes to the Python automation scripts

---

## 1. Shared UI Patterns

Reusable components applied consistently across all screens.

### 1A — Toast Notification System

- Overlay widget positioned bottom-right, stacking upward
- Severity-colored: green (success), orange (warning), red (error), blue (info)
- Auto-dismiss after 5s; errors persist until manually dismissed
- Error and warning toasts create a persistent notification in the bell flyout via `NotificationService`. Success and info toasts are transient only (no DB write) to avoid notification noise.
- Available from any screen — triggered through `NotificationService.showToast()`

**New widget:** `ToastOverlay` — wraps the app shell, listens to a toast stream from `NotificationService`
**New widget:** `ToastCard` — individual toast with icon, title, subtitle, dismiss button

### 1B — Inline Loading States

- Buttons show spinner + verb during operation ("Scoring...", "Replacing...", "Starting...")
- Disabled during loading to prevent double-clicks
- Brief success state (checkmark + past tense) for 2s, then reverts to normal
- Error state shows red text briefly, then reverts

**New widget:** `LoadingButton` — wraps Fluent UI's `FilledButton`/`Button` with loading/success/error state machine
**States:** `idle` → `loading` → `success`/`error` → `idle` (auto-revert after 2s)

### 1C — Multi-Select Pattern

- Checkbox column as first column in tables that support selection
- Contextual `SelectionToolbar` slides in above the table when 1+ rows selected
- Toolbar shows: select-all checkbox, count, available actions, "Clear selection" link
- Shift+click for range select, Ctrl+click for toggle
- Actions in toolbar are contextual (only valid actions for current selection)

**New widget:** `SelectionToolbar` — animated toolbar with action buttons
**State:** Selection and filter state extracted into a new `StatusSelectionController` (separate from `StatusController` to respect the 300-line ceiling). `StatusController` delegates selection/filter operations to it.

### 1D — Collapsible Sections

- Uses Fluent UI's `Expander` widget with custom styling
- Section header shows summary badge even when collapsed (e.g., "92 Excellent", "12 rotations")
- Animated expand/collapse
- Remembers open/closed state per session (stored in controller, not persisted)

**Pattern:** Applied to Proxy Detail sections, Dashboard sections if content grows

---

## 2. Accounts Table Redesign

### 2A — Search & Filter Bar

New bar below the page header, above the table:

- **Search box** (300px max width): debounced 300ms, matches account name, email, character name
- **Status filter dropdown** (pill): All / Running / Stopped / Banned / Awaiting
- **Script filter dropdown** (pill): All / filter by assigned script name
- **Result count**: "Showing X of Y" (live-updating)

Filters persist during session, clear on tab switch.

### 2B — Table Column Changes

Current columns (7): Account Name | Email | Password | Character | Proxy | Status | Actions

New columns (7 + checkbox): ☐ | Account | Credentials | Character | Script | Proxy | Status | Actions

Changes:
- **Checkbox column** added as first column (multi-select from 1C)
- **Credentials column** merges Email + Password into one cell (email on top, password below, each with copy icon). Saves a full column width.
- **Script column** (new) shows the character's default script as a clickable blue chip (`ScriptChip`). Clicking opens a `ScriptPickerFlyout` (reuses the existing `script_selector.dart` component wrapped in a Fluent UI `Flyout`).
  - No script assigned: dashed yellow "+ Assign script" prompt
  - Banned character: script name shown with strikethrough
  - No character: dash (scripts are per-character)
- **Proxy column** shows slot name + country code (e.g., "slot-3 (US)") instead of raw proxy address
- **Banned rows** get subtle red background tint
- **Play button disabled** when no script is assigned — forces assignment first

### 2C — Default Script & "Start All" Flow

Each character can have a `defaultScriptName` (nullable TEXT). This matches the existing string-based script model used by `LaunchConfig` and `NativeCommandsService.runGameClient` — there is no scripts table in the database.

**Start All / Start Selected behavior:**
1. System checks which selected characters have a default script assigned
2. If all have scripts → launches immediately, no dialog. Toast: "Starting N characters..."
3. If some lack scripts → `BulkStartConfirmationDialog`: "3 of 15 characters have no script. Start the 12 that do?" with "Start 12" / "Cancel" buttons
4. Per-character toast feedback as each bot starts (or fails)

**Single row play button** still opens the Launch Dialog for one-off overrides (script, world, flags).

### 2D — Selection Toolbar Integration

- Toolbar slides in above the table (animated) when any row is checked
- Replaces the Bot Farm Summary Bar temporarily
- Contains: select-all checkbox, "N selected" count, "Start Selected" button, "Stop Selected" button, "Clear selection" link
- Bot Farm Summary Bar returns when selection is cleared
- Start All / Stop All buttons on the summary bar now use `LoadingButton` pattern

---

## 3. Proxy Detail Pane Redesign

### 3A — Slot Header (merged with connection info)

The current separate "Current IP Details" card is absorbed into the slot header. All connection info displayed as compact inline badges:

- **IP address** (monospace)
- **Location**: City, Region, Country (e.g., "New York, NY, US") — region from new IPQS field
- **ISP**: from new IPQS `ISP` field (replaces old ASN name)
- **Connection type badge**: color-coded pill
  - Residential = green (ideal)
  - Datacenter = red (risky)
  - Corporate = orange (moderate)
  - Education = blue (low risk)
- **Assigned age**: relative time (e.g., "3d ago")
- **Actions**: Change IP, Launch Browser (always visible)

### 3B — Fraud Analysis Section (collapsible, expanded by default)

Replaces the current ScoreSummary + ScoreDetailTable + ScoreFlags with an accurate layout:

**Left: Fraud Score Circle**
- Shows raw IPQS `fraud_score` (0-100, lower = better)
- Label: "Fraud Risk" (not "IP Score")
- Color: green (0-30), yellow (31-60), orange (61-80), red (81-100)
- Caption below circle: "0 = clean, 100 = fraud"
- The `FraudAnalysis` widget reads from the `fraudScore` field on `ProxyIpAddressEntity`
- The existing `ipScore` (inverted 100-fraudScore), `scoreLevel`, `IpScoreLevel` enum, and `getScoreLevel()` static method are deprecated — they remain in the entity for backward compatibility during migration but are no longer used by any UI component. The collapsed header badge derives its label directly from `fraudScore` ranges.

**Right: Detection Flags (2-column grid)**
6 boolean flags displayed as checkmark (clean) or X (detected):
- VPN (from `isVpn`)
- Proxy (from `isProxy`)
- Tor (from `isTor`)
- Datacenter (from `isDatacenter`)
- Crawler (from `isCrawler` — **new**, currently not stored)
- Recent Abuse (from `recentAbuse` — **fixed**, stored as boolean not 0/100)

**Flagged state:** detected flags get red background + border + bold text and sort to the top of the grid.

**Footer:** "Last checked" timestamp + "Refresh Score" button (LoadingButton pattern)

**Collapsed header badge:** shows "Score: 8 — Excellent" or "Score: 85 — Poor" with color

### 3C — IP History Section (collapsible, collapsed by default)

- Collapsed summary: "12 rotations · Avg score: 78"
- Expanded: same IP history list as current (last 10 entries)
- No functional changes, just collapsible wrapping

### 3D — Linked Characters Section (collapsible, collapsed by default) — NEW

- Collapsed summary: "2 characters"
- Expanded: list of characters using this proxy slot (name, status, script)
- Clickable: navigates to that character in the Accounts tab

### 3E — Low Score State

When fraud score > 60:
- Red left border on slot header card
- "Replace Proxy" promoted to primary action (red FilledButton) in slot header
- Inline warning bar: "Low fraud score — this IP may be flagged. Consider replacing the proxy."

---

## 4. Dashboard Redesign

Replaces: 3 stat cards, character status progress bars, empty "Recent Activity" placeholder.

### 4A — Bot Farm Status Grid

Top section. Responsive grid of character tiles:

**Each tile shows:**
- Character name (bold)
- Default script name (or "No script" in muted text)
- Proxy slot + country code
- Uptime (e.g., "2h 14m") for running bots, "idle" for stopped. Uptime is computed from `TrackedClient.launchedAt` which is ephemeral (in-memory). After app restart, running bots show "uptime unknown" until they are re-launched through the app.

**Color-coded left border:** green (running), grey (stopped), orange (restarting), red (banned)

**Header:** "Bot Farm Status" + status count badges (N running, N stopped, N banned) + Start All / Stop All buttons

**Interactions:**
- Tiles are clickable — navigates to that character in the Accounts tab
- Start All / Stop All use default-script logic from Section 2C
- Grid reflows responsively based on window width

### 4B — Proxy Health Overview

Middle section. Shows fleet-wide proxy health:

**Stacked health bar:** proportional segments colored by score level (Excellent/Good/Fair/Poor/Unscored) with count labels

**"Needs Attention" card:** only appears if problems exist. Lists:
- Slots with high fraud scores — with inline "Replace" button
- Unscored slots — with inline "Score" button
- Each row shows: slot name, fraud score, connection type badge

Hidden entirely when all proxies are healthy (no noise when things are fine).

### 4C — Quick Actions

Bottom section. Card grid with shortcuts:

- **New Character** — opens CreateCharacterDialog
- **Score All IPs** — triggers batch IPQS scoring (LoadingButton on card)
- **Sync Proxies** — triggers Webshare sync (LoadingButton on card)
- **Settings** — navigates to Settings tab

Responsive grid: 2-4 columns based on window width.

---

## 5. Data Model Changes

### DB Migration v5

**ProxyIpAddressesTable — new columns:**

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `isCrawler` | BOOL nullable | IPQS `is_crawler` | Bot/crawler detection |
| `connectionType` | TEXT nullable | IPQS `connection_type` | "residential", "datacenter", "corporate", etc. |
| `isp` | TEXT nullable | IPQS `ISP` | Internet Service Provider name |
| `organization` | TEXT nullable | IPQS `organization` | Organization name |
| `region` | TEXT nullable | IPQS `region` | State/province |

**ProxyIpAddressesTable — column changes:**

| Column | Change | Migration Strategy |
|--------|--------|-------------------|
| `abuseConfidence` (INT) | Add new `recentAbuse` (BOOL nullable) alongside | Add new column, populate from old (`abuseConfidence >= 50 → true`, `0 → false`, `null → null`). Keep `abuseConfidence` column in DB (Drift ignores unmapped columns) but remove from Drift table definition and entity. No table recreation needed. |

**CharactersTable — new columns:**

| Column | Type | Notes |
|--------|------|-------|
| `defaultScriptName` | TEXT nullable | Script name string matching `LaunchConfig.scriptName`. The default script to run for "Start All" |

### API Client Changes

**IpqsApiClient:** `IpqsResult` already parses all needed fields (`isCrawler`, `recentAbuse`, `connectionType`, `isp`, `organization`, `region`) — they are just not stored to DB. No API client changes needed; only the storage/mapping layer needs updating.

**ProxyScoringController:** Update `copyWith` mapping in `scoreIpWithIpqs()` to include all new fields (`isCrawler`, `connectionType`, `isp`, `organization`, `region`, `recentAbuse` as bool).

### Entity Changes

**ProxyIpAddressEntity:** Add `isCrawler`, `connectionType`, `isp`, `organization`, `region` fields. Change `abuseConfidence` (int) to `recentAbuse` (bool).

**CharacterEntity:** Add `defaultScriptName` field.

---

## 6. New Widgets Summary

| Widget | Location | Purpose |
|--------|----------|---------|
| `ToastOverlay` | `core/widgets/` | App-level overlay for toast notifications |
| `ToastCard` | `core/widgets/` | Individual toast notification card |
| `LoadingButton` | `core/widgets/` | Button with loading/success/error states |
| `SelectionToolbar` | `core/widgets/` | Contextual toolbar for multi-select tables |
| `CollapsibleSection` | `core/widgets/` | Expander wrapper with summary badge |
| `FraudAnalysis` | `feature/proxy/views/components/` | Replaces ScoreSummary + ScoreDetailTable + ScoreFlags |
| `LinkedCharactersSection` | `feature/proxy/views/components/` | New: characters using this proxy |
| `BotStatusGrid` | `feature/main_menu/views/sections/` | Dashboard bot tile grid |
| `ProxyHealthOverview` | `feature/main_menu/views/sections/` | Dashboard proxy health bar + attention list |
| `QuickActionsSection` | `feature/main_menu/views/sections/` | Dashboard quick action cards |
| `SearchFilterBar` | `feature/Status/views/components/` | Accounts search + dropdown filters |
| `ScriptChip` | `feature/Status/views/components/` | Clickable script badge for table rows |
| `ScriptPickerFlyout` | `feature/Status/views/components/` | Flyout wrapping existing script_selector for inline script assignment |
| `BulkStartConfirmationDialog` | `feature/Status/views/dialogs/` | Confirmation when some selected characters lack scripts |
| `BotStatusTile` | `feature/main_menu/views/components/` | Individual character tile in the bot grid |

## 7. Files Modified (Existing)

| File | Changes |
|------|---------|
| `feature/app.dart` | Wrap content with `ToastOverlay` |
| `feature/Status/views/status_screen.dart` | Add SearchFilterBar, integrate SelectionToolbar |
| `feature/Status/views/sections/account_list_section.dart` | New column layout (checkbox + credentials merge + script), filter logic |
| `feature/Status/views/components/bot_farm_summary_bar.dart` | LoadingButton on Start All / Stop All |
| `feature/Status/controller/status_controller.dart` | Delegate selection/filter to new StatusSelectionController |
| `feature/Status/controller/status_selection_controller.dart` | **New:** Selection state, filter state, bulk start/stop logic (extracted to respect 300-line ceiling) |
| `feature/proxy/views/sections/proxy_detail_section.dart` | Collapsible sections, merged header |
| `feature/proxy/views/components/ip_score_analysis.dart` | Delete (replaced by new `fraud_analysis.dart`) |
| `feature/proxy/views/components/score_summary.dart` | Delete (absorbed into `FraudAnalysis` widget) |
| `feature/proxy/views/components/score_detail_table.dart` | Delete (replaced by flag grid in `FraudAnalysis`) |
| `feature/proxy/views/components/score_flags.dart` | Delete (merged into `FraudAnalysis`) |
| `feature/proxy/views/components/current_ip_card.dart` | Delete (merged into slot header) |
| `feature/proxy/views/components/ip_score_indicator.dart` | Update to display `fraudScore` (raw, lower=better) instead of inverted `ipScore` |
| `feature/proxy/controller/proxy_scoring_controller.dart` | Map new IPQS fields in `copyWith`; migrate `_recalculateStats()` and `getLowScoreSlotDetails()` to use `fraudScore` ranges instead of inverted `ipScore` |
| `feature/main_menu/views/main_menu_screen.dart` | Replace content with new sections |
| `feature/main_menu/views/sections/system_overview_section.dart` | Remove (replaced by BotStatusGrid) |
| `feature/main_menu/views/sections/characters_status_section.dart` | Remove (replaced by BotStatusGrid) |
| `feature/main_menu/views/sections/recent_activity_section.dart` | Remove (replaced by QuickActionsSection) |
| `feature/main_menu/controller/main_menu_controller.dart` | Add observable state: `botStatusTiles` (List<BotTileData>), `proxyHealthStats` (ProxyHealthData), `quickActionStates` (loading flags). Reads from DatabaseService + WatchdogService. |
| `data/database/tables/proxy_ip_addresses_table.dart` | Add new columns |
| `data/database/tables/accounts_table.dart` | Add `defaultScriptName` TEXT nullable column to `CharactersTable` (defined in this file alongside `AccountsTable`) |
| `data/database/app_database.dart` | Migration v5 |
| `domain/entities/proxy_ip_address.dart` | Add new fields, change abuseConfidence → recentAbuse |
| `domain/entities/character.dart` | Add `defaultScriptName` field |
| `data/repositories/proxy_repository_impl.dart` | Update `_mapIpAddressRow`, `insertIpAddress`, `updateIpAddress` to map new columns (`isCrawler`, `connectionType`, `isp`, `organization`, `region`, `recentAbuse`) |
| `feature/proxy/data/proxy_ip_address_model.dart` | Delete — legacy duplicate of `ProxyIpAddressEntity`. Remove any references. |
| `config/services/notification_service.dart` | Add toast stream for ToastOverlay |
| `config/services/proxy/proxy_auto_rotation_service.dart` | Replace `abuseConfidence` with `recentAbuse: scoreResult.recentAbuse`; migrate `ipScore`/`getScoreLevel()` usage to `fraudScore` ranges |
| `config/services/proxy/proxy_sync_service.dart` | Replace `abuseConfidence: 0` with `recentAbuse: false` in entity construction sites |
| `feature/proxy/views/components/slot_header.dart` | Migrate `ipScore` display to `fraudScore` |
| `feature/proxy/views/components/proxy_slot_card_header.dart` | Migrate `ipScore` display to `fraudScore` |
| `feature/proxy/views/components/ip_history_list.dart` | Migrate `ipScore` display to `fraudScore` |
| `feature/proxy/views/components/replace_proxy_button.dart` | Migrate `ipScore` threshold to `fraudScore` range |
| `feature/proxy/views/dialogs/replace_proxy_dialog.dart` | Migrate `ipScore` threshold to `fraudScore` range |
| `feature/proxy/controller/proxy_controller.dart` | Migrate sort comparator from `ipScore` to `fraudScore` |
