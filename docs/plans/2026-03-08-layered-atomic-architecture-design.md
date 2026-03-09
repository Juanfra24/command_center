# Layered Atomic Architecture - Design Document

**Date:** 2026-03-08
**Status:** Approved
**Goal:** Decompose heavy files into atomic components with enforceable line limits. Decouple logic from UI. Establish standards to prevent file bloat.

## Problem

Seven files exceed 500 lines. Screen files mix layout, dialogs, and business logic. Controllers act as god objects. Services combine HTTP transport with orchestration.

| File | Lines | Issue |
|------|-------|-------|
| proxy_screen.dart | 1,774 | Massive widget tree + inline dialogs |
| app.dart | 1,690 | App shell + onboarding + settings + config dialogs |
| status_screen.dart | 835 | Account list + character creation dialog |
| proxy_controller.dart | 742 | Sync + scoring + filtering + stats + editing |
| automation_service.dart | 624 | Multiple task types + process spawning + result parsing |
| webshare_service.dart | 524 | Dual API versions + config management |
| proxy_repository_impl.dart | 341 | 30+ methods, no layering |

## Architecture: Layered Atomic

### File Standards

| Layer | Max Lines | Responsibility | Naming |
|-------|-----------|----------------|--------|
| Screen | 150 | Layout shell — compose sections, no logic | `*_screen.dart` |
| Section | 300 | Meaningful chunk of a screen | `*_section.dart` |
| Component | 200 | Reusable widget, single visual concern | descriptive name |
| Dialog | 200 | Always separate file, never inline | `*_dialog.dart` |
| Controller | 300 | Presentation state only — delegates to services | `*_controller.dart` |
| Service | 250 | Single domain responsibility, orchestration | `*_service.dart` |
| API Client | 200 | HTTP transport only, returns parsed models | `*_api_client.dart` |

### Rules

- Screens never call services directly — go through controllers
- Controllers never make HTTP calls — go through services
- Services never build widgets or hold UI state
- Dialogs receive data via constructor params, return results via Navigator.pop
- Components are StatelessWidget unless they need local animation/form state
- Every external API gets `*_api_client.dart` (HTTP) + `*_service.dart` (logic)

## Decomposition Plan

### 1. Proxy Feature

**Current:** proxy_screen.dart (1,774) + proxy_controller.dart (742)

**Views:**
```
feature/proxy/views/
├── proxy_screen.dart                    (<=150) Layout shell: master-detail scaffold
├── sections/
│   ├── proxy_list_section.dart          (<=300) Slot list + search/filter bar
│   └── proxy_detail_section.dart        (<=300) Selected slot info + tabs
├── components/
│   ├── proxy_slot_card.dart             (<=200) Single slot row
│   ├── ip_score_indicator.dart          (<=100) Score badge/ring
│   ├── ip_history_list.dart             (<=200) IP history table
│   ├── ip_score_analysis.dart           (<=200) Fraud flags, VPN/Tor/DC chips
│   ├── slot_header.dart                 (<=150) Slot name + action buttons
│   └── replace_proxy_button.dart        (<=100) Orange replace button
└── dialogs/
    ├── replace_proxy_dialog.dart        (<=200) Country selection + confirmation
    └── ip_detail_dialog.dart            (<=200) Full IP info overlay
```

**Controllers:**
```
feature/proxy/controller/
├── proxy_controller.dart                (<=300) Presentation state: selection, filtering, search
└── proxy_scoring_controller.dart        (<=200) Scoring UI state, batch progress
```

**Services:**
```
config/services/proxy/
├── proxy_sync_service.dart              (<=250) Webshare sync logic (create/update/soft-delete)
└── proxy_replacement_service.dart       (<=200) IP rotation + replacement
```

### 2. App Shell

**Current:** app.dart (1,690)

**Views:**
```
feature/app/views/
├── app_screen.dart                      (<=150) NavigationView shell + pane setup
├── sections/
│   ├── settings_section.dart            (<=300) Theme, API keys, about
│   └── onboarding_section.dart          (<=250) Setup checklist + progress
├── components/
│   ├── setup_checklist_item.dart        (<=100) Single checklist row
│   └── navigation_pane_builder.dart     (<=150) Pane items construction
└── dialogs/
    ├── webshare_config_dialog.dart      (<=200) API key input + test
    └── ipqs_config_dialog.dart          (<=200) API key input + test
```

**Controller:**
```
feature/app/controller/
└── app_controller.dart                  (<=250) Nav index, onboarding state, theme
```

### 3. Status/Accounts Feature

**Current:** status_screen.dart (835)

**Views:**
```
feature/Status/views/
├── status_screen.dart                   (<=150) Layout shell
├── sections/
│   └── account_list_section.dart        (<=250) Account list with process status
├── components/
│   ├── account_card.dart                (<=200) Single account row
│   ├── character_row.dart               (<=150) Character + skills + status
│   └── process_status_badge.dart        (<=100) Running/stopped indicator
└── dialogs/
    └── create_character_dialog.dart     (<=200) Character creation form
```

### 4. Services Layer

**Webshare (524 -> 2 files):**
```
config/services/webshare/
├── webshare_api_client.dart             (<=200) HTTP: getProxyList, replaceProxy, getPlan
└── webshare_service.dart                (<=200) API key management, config sync, error handling
```

**Automation (624 -> 4 files):**
```
config/services/automation/
├── automation_result.dart               (<=80)  AutomationResult + AutomationStatus
├── python_runner.dart                   (<=200) Process spawning, streams, timeout/cancel
├── result_parser.dart                   (<=100) JSON extraction from stdout
└── automation_service.dart              (<=250) Orchestration: validate, create, session
```

**IPQS (262 -> 2 files):**
```
config/services/ipqs/
├── ipqs_api_client.dart                 (<=150) HTTP transport, returns IpqsResult
└── ipqs_service.dart                    (<=150) Config management, scoring orchestration
```

**Unchanged (already within limits):**
- app_config_service.dart (142)
- onboarding_service.dart (172)
- native_commands_service.dart (67)
- python_setup_service.dart (294)

## Target Metrics

- Largest file: ~300 lines (down from 1,774)
- Files over 500 lines: 0 (down from 7)
- ~38 new focused files, each with single responsibility
- Every file fits within its layer's line ceiling
