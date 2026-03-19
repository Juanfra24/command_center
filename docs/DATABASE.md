# Database Schema Documentation

Command Center uses [Drift ORM](https://drift.simonbinder.eu/) (SQLite) for local persistence. The database file is stored at:

```
<AppDocumentsDirectory>/command_center.db
```

On Windows this is typically `C:\Users\<user>\Documents\command_center.db`.

## Entity-Relationship Diagram

```
┌─────────────────────┐
│   AppConfigTable     │
│─────────────────────│
│ PK key       TEXT    │
│    value     TEXT    │
│    createdAt DATETIME│
│    lastUpdated       │
│         DATETIME     │
└─────────────────────┘

┌─────────────────────┐       ┌──────────────────────────┐
│   ProxySlotsTable    │──1:N─→│  ProxyIpAddressesTable   │
│─────────────────────│       │──────────────────────────│
│ PK id       INTEGER  │       │ PK id          INTEGER   │
│    webshareId TEXT    │       │ FK slotId       INTEGER  │
│    slotName   TEXT    │       │    ipAddress    TEXT      │
│    slotNumber INTEGER │       │    hostname     TEXT      │
│    currentIpAddressId │       │    isActive     BOOLEAN   │
│          INTEGER?     │       │    countryCode  TEXT      │
│    username   TEXT    │       │    cityName     TEXT      │
│    password   TEXT    │       │    ipTimezone   TEXT      │
│    port      INTEGER  │       │    highCountryConfidence  │
│    createdAt DATETIME │       │               BOOLEAN    │
│    lastUpdated        │       │    asnName     TEXT      │
│          DATETIME     │       │    asnNumber   INTEGER   │
│    totalIpChanges     │       │    ipScore     REAL      │
│          INTEGER      │       │    scoreLevel  TEXT      │
│    isActive  BOOLEAN  │       │    isVpn       BOOLEAN   │
│    isDeleted BOOLEAN  │       │    isProxy     BOOLEAN   │
│    deletedAt DATETIME?│       │    isDatacenter BOOLEAN  │
└──────────┬──────────┘       │    isTor       BOOLEAN   │
           │                   │    fraudScore  REAL      │
           │                   │    abuseConfidence       │
           │                   │               INTEGER    │
           │                   │    assignedAt  DATETIME  │
           │                   │    removedAt   DATETIME? │
           │                   │    lastVerification      │
           │                   │               DATETIME   │
           │                   │    lastScoreCheck        │
           │                   │               DATETIME?  │
           │                   │    totalDaysUsed INTEGER │
           │                   │    timesAssigned INTEGER │
           │                   └──────────────────────────┘
           │
           │ N:1
           │
┌──────────┴──────────┐       ┌─────────────────────────┐
│   AccountsTable      │──1:N─→│   CharactersTable       │
│─────────────────────│       │─────────────────────────│
│ PK id       INTEGER  │       │ PK id          INTEGER  │
│    accountName TEXT   │       │ FK accountId   INTEGER  │
│    birthday    TEXT   │       │    name         TEXT     │
│    email       TEXT   │       │    banned       BOOLEAN  │
│    password    TEXT   │       │    actualSkillsJson TEXT │
│ FK proxySlotId       │       │    targetSkillsJson TEXT │
│          INTEGER?     │       │    createdAt   DATETIME │
│    createdAt DATETIME │       │    lastUpdated DATETIME │
│    lastUpdated        │       └─────────────────────────┘
│          DATETIME     │
└─────────────────────┘

┌─────────────────────────┐
│   NotificationsTable     │
│─────────────────────────│
│ PK id          INTEGER   │
│    type         TEXT      │
│    severity     TEXT      │
│    title        TEXT      │
│    message      TEXT      │
│    isRead       BOOLEAN   │
│    createdAt    DATETIME  │
│    readAt       DATETIME? │
└─────────────────────────┘
```

## Tables

### AppConfigTable

Key-value store for application configuration (API keys, theme, etc.).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `key` | TEXT | **PK** | Configuration key |
| `value` | TEXT | | Value (JSON string for complex types) |
| `createdAt` | DATETIME | default: now | When the entry was created |
| `lastUpdated` | DATETIME | default: now | When the entry was last modified |

**Source:** `lib/data/database/tables/app_config_table.dart`

### ProxySlotsTable

Webshare proxy slots. Supports soft deletion via `isDeleted`/`deletedAt`.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | **PK**, auto-increment | |
| `webshareId` | TEXT | unique | Webshare proxy ID |
| `slotName` | TEXT | default: `''` | User-defined label |
| `slotNumber` | INTEGER | unique | Ordering index |
| `currentIpAddressId` | INTEGER | nullable | FK to active IP (informal, no DB constraint) |
| `username` | TEXT | | Proxy auth username |
| `password` | TEXT | | Proxy auth password |
| `port` | INTEGER | default: 0 | Proxy port |
| `createdAt` | DATETIME | default: now | |
| `lastUpdated` | DATETIME | default: now | |
| `totalIpChanges` | INTEGER | default: 0 | Cumulative IP rotation count |
| `isActive` | BOOLEAN | default: true | Whether the slot is in use |
| `isDeleted` | BOOLEAN | default: false | Soft-delete flag |
| `deletedAt` | DATETIME | nullable | When the slot was soft-deleted |

**Source:** `lib/data/database/tables/proxy_slots_table.dart`

### ProxyIpAddressesTable

IP address history for each proxy slot, including IPQS quality scoring data.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | **PK**, auto-increment | |
| `ipAddress` | TEXT | | The IP address |
| `hostname` | TEXT | default: `''` | Hostname |
| `slotId` | INTEGER | **FK** -> ProxySlotsTable.id | Parent proxy slot |
| `isActive` | BOOLEAN | default: false | Currently active for its slot |
| `countryCode` | TEXT | default: `'XX'` | Country code (e.g., `US`) |
| `cityName` | TEXT | default: `''` | City name |
| `ipTimezone` | TEXT | default: `'UTC'` | Timezone string |
| `highCountryConfidence` | BOOLEAN | default: false | GeoIP confidence flag |
| `asnName` | TEXT | default: `''` | ASN provider name |
| `asnNumber` | INTEGER | default: 0 | ASN number |
| `ipScore` | REAL | default: 0.0 | Composite quality score (0-100) |
| `scoreLevel` | TEXT | default: `'unknown'` | Level: excellent/good/fair/poor/bad/unknown |
| `isVpn` | BOOLEAN | default: false | Detected as VPN |
| `isProxy` | BOOLEAN | default: true | Detected as proxy |
| `isDatacenter` | BOOLEAN | default: false | Datacenter IP |
| `isTor` | BOOLEAN | default: false | TOR exit node |
| `fraudScore` | REAL | default: 0.0 | Fraud score |
| `abuseConfidence` | INTEGER | default: 0 | Abuse confidence (0-100) |
| `assignedAt` | DATETIME | default: now | When the IP was assigned |
| `removedAt` | DATETIME | nullable | When the IP was replaced |
| `lastVerification` | DATETIME | default: now | Last proxy validation |
| `lastScoreCheck` | DATETIME | nullable | Last IPQS scoring check |
| `totalDaysUsed` | INTEGER | default: 0 | Days this IP has been used |
| `timesAssigned` | INTEGER | default: 1 | Assignment count |

**Source:** `lib/data/database/tables/proxy_ip_addresses_table.dart`

### AccountsTable

Jagex accounts managed by the bot system.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | **PK**, auto-increment | |
| `accountName` | TEXT | | Display name |
| `birthday` | TEXT | default: `'01-01-2000'` | Birthday string |
| `email` | TEXT | unique | Login email |
| `password` | TEXT | | Account password |
| `proxySlotId` | INTEGER | nullable, **FK** -> ProxySlotsTable.id | Assigned proxy |
| `createdAt` | DATETIME | default: now | |
| `lastUpdated` | DATETIME | default: now | |

**Source:** `lib/data/database/tables/accounts_table.dart`

### CharactersTable

Game characters belonging to accounts. Each account can have multiple characters.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | **PK**, auto-increment | |
| `accountId` | INTEGER | **FK** -> AccountsTable.id | Parent account |
| `name` | TEXT | | In-game character name |
| `banned` | BOOLEAN | default: false | Whether the character is banned |
| `actualSkillsJson` | TEXT | default: `'{}'` | Current skills (JSON) |
| `targetSkillsJson` | TEXT | default: `'{}'` | Target skills (JSON) |
| `createdAt` | DATETIME | default: now | |
| `lastUpdated` | DATETIME | default: now | |

**Source:** `lib/data/database/tables/accounts_table.dart`

### NotificationsTable

Persistent notifications for the UI notification bell/flyout.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | **PK**, auto-increment | |
| `type` | TEXT | | Notification type (e.g., `auto_rotation`, `ban_detection`) |
| `severity` | TEXT | default: `'info'` | Severity level: info, warning, error |
| `title` | TEXT | | Notification title |
| `message` | TEXT | | Notification body |
| `isRead` | BOOLEAN | default: false | Whether the user has dismissed it |
| `createdAt` | DATETIME | default: now | When the notification was created |
| `readAt` | DATETIME | nullable | When the notification was read |

**Source:** `lib/data/database/tables/notifications_table.dart`

## Relationships

```
ProxySlotsTable  1 ──→ N  ProxyIpAddressesTable   (via slotId FK)
AccountsTable    1 ──→ N  CharactersTable          (via accountId FK)
ProxySlotsTable  1 ──→ N  AccountsTable            (via proxySlotId FK, nullable)
```

- A **proxy slot** has many **IP addresses** (history of rotations).
- An **account** has many **characters** (game profiles).
- An **account** optionally belongs to one **proxy slot**; a proxy slot can serve multiple accounts.

Foreign keys are enforced at runtime via `PRAGMA foreign_keys = ON` (set in `beforeOpen`).

## Schema Version & Migrations

**Current version:** 4

The schema version is declared in `lib/data/database/app_database.dart`:

```dart
@override
int get schemaVersion => 4;
```

### Migration History

| Version | Change |
|---------|--------|
| 1 | Initial schema (5 tables: AppConfig, ProxySlots, ProxyIpAddresses, Accounts, Characters) |
| 2 | Added `isDeleted` and `deletedAt` columns to `ProxySlotsTable` (soft delete) |
| 3 | Added `ON DELETE CASCADE` to `CharactersTable.accountId` FK (copy-and-recreate) |
| 4 | Added `NotificationsTable` for persistent notification system |

### How Migrations Work

Drift uses a `MigrationStrategy` with three hooks:

- **`onCreate`** -- Called on first launch. Runs `m.createAll()` to create every table.
- **`onUpgrade`** -- Called when `schemaVersion` increases. Receives `from` and `to` version numbers. Write incremental migration steps guarded by `if (from < N)`.
- **`beforeOpen`** -- Runs every time the database opens. Used to enable foreign keys.

### Adding a New Column

1. Add the column definition to the table class in `lib/data/database/tables/`.
2. Bump `schemaVersion` in `app_database.dart`.
3. Add a migration step in `onUpgrade`:
   ```dart
   if (from < NEW_VERSION) {
     await m.addColumn(tableName, tableName.newColumn);
   }
   ```
4. Regenerate Drift code:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

### Adding a New Table

1. Create a new table class in `lib/data/database/tables/`.
2. Export it from `lib/data/database/tables/tables.dart`.
3. Add the table to the `@DriftDatabase(tables: [...])` annotation in `app_database.dart`.
4. Bump `schemaVersion`.
5. Add a migration step:
   ```dart
   if (from < NEW_VERSION) {
     await m.createTable(newTable);
   }
   ```
6. Regenerate Drift code.

### Altering Constraints (e.g., Foreign Key Actions)

SQLite does not support `ALTER TABLE` for constraints. Use the copy-and-recreate pattern:

```dart
if (from < NEW_VERSION) {
  await m.issueCustomQuery(
    'CREATE TABLE backup AS SELECT * FROM target_table',
  );
  await m.issueCustomQuery('DROP TABLE target_table');
  await m.createTable(targetTable);  // recreated with new constraints
  await m.issueCustomQuery(
    'INSERT INTO target_table SELECT * FROM backup',
  );
  await m.issueCustomQuery('DROP TABLE backup');
}
```

## Code Generation

After any table change, regenerate the Drift companion code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This updates `lib/data/database/app_database.g.dart` with the new schema, companion classes, and type-safe query helpers.

## Backup & Recovery

The database is a single SQLite file at:

```
<getApplicationDocumentsDirectory()>/command_center.db
```

To back up, simply copy this file while the app is closed. To restore, replace the file and relaunch the app. Drift will run any necessary migrations if the schema version has changed.
