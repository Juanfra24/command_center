# Bot Scripts Framework & Phase 1 Scripts — Design Spec

## Goal

Build a reusable script framework for Microbot_Frieren that makes writing, testing, and maintaining bot scripts fast and consistent. Deliver 5 F2P scripts as the first consumers of the framework. Tutorial Island is deferred to a follow-up.

## Scope

**In scope:**
- `CCScript<S>` base class with template methods, lifecycle management, and Status API wiring
- Component-based behavior system (eating, banking, looting, bone burying, death recovery, stuck detection)
- Shared test harness (`MockGameEnvironment`) for mocking Rs2* utilities
- 3-layer test strategy: behavior tests, state machine tests, contract tests
- 5 scripts: Woodcutter, Miner, Fisher, Cooker, F2P Combat Trainer

**Out of scope:**
- Tutorial Island (deferred — most complex script, no upstream reference)
- Quest Runner, AIO Skiller, Members Prep (Phase 2)
- P2P money-making scripts (Phase 3)
- XP tracking integration in BotStatusModel (placeholder exists, wired later)

## Repo

All code lives in `Microbot_Frieren` under:
```
runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/
```

No Dart-side (Command Center) changes needed — the CC integration from Plan 2 already handles script names, Status API polling, and profile writing.

---

## Part 1: Framework Core — `CCScript<S>`

### Responsibility

Abstract base class that every CC script extends. Handles lifecycle, status reporting, antiban setup, stuck detection, and death recovery so scripts only implement game-specific logic.

### Template Methods (scripts implement)

| Method | Purpose |
|--------|---------|
| `configure()` | Register behaviors, set antiban activity template |
| `getInitialState()` | Return the starting state enum value |
| `onTick(S currentState)` | Main per-tick logic, returns next state |

### Framework-Provided Lifecycle

| Concern | Implementation |
|---------|---------------|
| **Status API** | Calls `BotStatusModel.setActiveScript(descriptorName, true)` on `run()`, `false` on `shutdown()`. Scripts never touch this. |
| **Antiban** | Calls `Rs2Antiban.resetAntibanSettings()` + configured template on `run()`, resets on `shutdown()`. |
| **Tick loop** | `scheduledExecutorService.scheduleWithFixedDelay()` at 600ms. Each tick: check `super.run()` guard → run behaviors by priority → if no behavior activated, call `onTick()` → update state. |
| **Shutdown** | Cancels scheduled future, resets all behaviors, resets antiban, reports inactive to Status API. |

### Class Signature

```java
public abstract class CCScript<S extends Enum<S>> extends Script {

    // --- Scripts implement these ---
    protected abstract void configure();
    protected abstract S getInitialState();
    protected abstract S onTick(S currentState);

    // --- Framework provides these ---
    protected final void registerBehavior(CCBehavior behavior);
    protected final void setActivityLocation(WorldPoint point);
    protected final void setAntiBanTemplate(Consumer<Rs2AntibanSettings> template);
    protected final S state();

    // --- Lifecycle ---
    public boolean run(Config config);
    @Override
    public void shutdown();
}
```

### Tick Execution Order

1. `super.run()` guard — blocks on tutorial island, blocking events, paused scripts
2. `Microbot.isLoggedIn()` check
3. `Rs2AntibanSettings.actionCooldownActive` check — skip tick if cooling down
4. Iterate behaviors by priority (ascending). First `shouldActivate() == true` → call `execute()`, skip remaining behaviors and `onTick()`.
5. If no behavior activated → call `onTick(currentState)` → update state with return value.
6. If state changed → reset stuck timer.

### Configuration

`CCScript` does NOT define a `Config` interface. Each script has its own `Config` extending RuneLite's `Config`. The framework is config-agnostic — scripts pass config values into behaviors during `configure()`.

---

## Part 2: Behavior System

### Interface

```java
public interface CCBehavior {
    int priority();           // Lower number = higher priority
    boolean shouldActivate(); // Checked every tick
    void execute();           // Perform the behavior's action
    void reset();             // Clean up on script shutdown
    String name();            // For logging/debugging
}
```

### Priority Ordering

| Priority | Behavior | Rationale |
|----------|----------|-----------|
| 1 | `StuckDetectionBehavior` | Safety net — must always check |
| 5 | `DeathRecoveryBehavior` | Can't do anything else while dead |
| 10 | `EatingBehavior` | Survival before anything else |
| 40 | `LootingBehavior` | Grab drops before banking |
| 45 | `BuryBonesBehavior` | Process bones before banking |
| 50 | `BankingBehavior` | Lowest priority — only when inventory management needed |

### Built-in Behaviors

#### `EatingBehavior`

**Constructor:** `EatingBehavior(int hpThresholdPercent)`

**shouldActivate:** Current HP < threshold % of max HP, and inventory contains food.

**execute:** Eat the best food available in inventory. Uses `Rs2Inventory` to find food items, `Rs2Player` to check HP.

**Key detail:** Does NOT interrupt combat — eats between attacks during the tick gap. The framework handles this naturally since behaviors run before `onTick()`.

#### `BankingBehavior`

**Constructor:** `BankingBehavior(BankingConfig config)`

```java
public class BankingConfig {
    final Predicate<Rs2Item> depositFilter;   // What to deposit (e.g., "logs", "raw fish")
    final List<WithdrawRequest> withdrawals;  // What to withdraw (optional)
    final WorldPoint returnLocation;          // Where to walk back (null = use activityLocation)
}
```

**shouldActivate:** `Rs2Inventory.isFull()` OR custom predicate (for combat scripts that bank on low food).

**execute:** Walk to nearest bank → open → deposit matching items → withdraw if configured → close → walk back to activity location.

**Key detail:** Uses `Rs2Bank.walkToBankAndUseBank()` for navigation. Saves and restores activity location so the script resumes where it left off.

#### `LootingBehavior`

**Constructor:** `LootingBehavior(List<String> itemNames, int radius)`

**shouldActivate:** Any configured item on ground within radius tiles.

**execute:** Pick up nearest matching item using `Rs2GroundItem`. One item per activation (multiple ticks for multiple items).

**Key detail:** `radius` defaults to 5 tiles. Only activates when the script is in an interruptible state (not mid-animation).

#### `BuryBonesBehavior`

**Constructor:** `BuryBonesBehavior()`

**shouldActivate:** Inventory contains bones (any type).

**execute:** Bury one bone per activation. Uses `Rs2Inventory.interact("Bones", "Bury")`.

**Key detail:** Only activates when not in combat (player idle). Real players bury between kills, not during.

#### `DeathRecoveryBehavior`

**Constructor:** `DeathRecoveryBehavior()`

**shouldActivate:** Death screen widget visible OR player at Lumbridge spawn without having walked there.

**execute:** Wait for respawn animation to complete → walk back to saved activity location.

**Key detail:** Uses `setActivityLocation()` saved by the script. If no location saved, logs warning and stays at spawn (script will re-initialize on next `onTick()`).

#### `StuckDetectionBehavior`

**Constructor:** `StuckDetectionBehavior(Duration timeout)` — default 5 minutes.

**shouldActivate:** Same state for longer than timeout AND no meaningful action detected (no animation, no movement, no inventory change).

**execute:** Log warning with current state name → reset script to initial state via `CCScript.resetToInitialState()`.

**Key detail:** The timer resets on any state change, player animation, or inventory change. This prevents false positives when the script is legitimately idle (e.g., waiting for a tree to respawn).

---

## Part 3: Script Implementations

### Naming & Package Convention

```
commandcenter/scripts/
├── core/                        # Framework
│   ├── CCScript.java
│   ├── CCBehavior.java
│   └── behaviors/
│       ├── EatingBehavior.java
│       ├── BankingBehavior.java
│       ├── BankingConfig.java
│       ├── LootingBehavior.java
│       ├── BuryBonesBehavior.java
│       ├── DeathRecoveryBehavior.java
│       └── StuckDetectionBehavior.java
├── woodcutting/
│   ├── CCWoodcuttingPlugin.java
│   ├── CCWoodcuttingScript.java
│   ├── CCWoodcuttingConfig.java
│   └── CCWoodcuttingOverlay.java
├── mining/
│   ├── CCMiningPlugin.java
│   ├── CCMiningScript.java
│   ├── CCMiningConfig.java
│   └── CCMiningOverlay.java
├── fishing/
│   ├── CCFishingPlugin.java
│   ├── CCFishingScript.java
│   ├── CCFishingConfig.java
│   └── CCFishingOverlay.java
├── cooking/
│   ├── CCCookingPlugin.java
│   ├── CCCookingScript.java
│   ├── CCCookingConfig.java
│   └── CCCookingOverlay.java
└── combat/
    ├── CCCombatPlugin.java
    ├── CCCombatScript.java
    ├── CCCombatConfig.java
    └── CCCombatOverlay.java
```

### `@PluginDescriptor` names (must match what Command Center sends)

| Script | Descriptor Name |
|--------|----------------|
| Woodcutting | `CC Woodcutter` |
| Mining | `CC Miner` |
| Fishing | `CC Fisher` |
| Cooking | `CC Cooker` |
| Combat | `CC Combat Trainer` |

### Plugin Pattern (same for all 5)

```java
@PluginDescriptor(
    name = "CC Woodcutter",
    description = "Chop trees, bank or drop logs",
    tags = {"microbot", "woodcutting", "f2p", "commandcenter"},
    enabledByDefault = false
)
@Slf4j
public class CCWoodcuttingPlugin extends Plugin {
    @Inject CCWoodcuttingScript script;
    @Inject CCWoodcuttingConfig config;
    @Inject OverlayManager overlayManager;
    @Inject CCWoodcuttingOverlay overlay;

    @Override
    protected void startUp() {
        overlayManager.add(overlay);
        script.run(config);
    }

    @Override
    protected void shutDown() {
        script.shutdown();
        overlayManager.remove(overlay);
    }
}
```

### Woodcutter (`CCWoodcuttingScript`)

**Adapted from:** `AutoWoodcuttingScript` (519 LOC upstream → ~120 LOC)

**States:** `CHOPPING`, `IDLE`

**Behaviors:** `BankingBehavior` (deposit logs), `StuckDetectionBehavior`, `DeathRecoveryBehavior`

**Config options:**
- `tree()` — enum: TREE, OAK, WILLOW, MAPLE, YEW (name + log item ID + tree object name)
- `action()` — enum: BANK, DROP
- `antiBan()` — boolean, default true

**onTick logic:**
```
CHOPPING:
  if player is animating → stay CHOPPING (tree being chopped)
  find nearest configured tree object
  if tree found → interact("Chop down") → stay CHOPPING
  if no tree found → IDLE

IDLE:
  find nearest configured tree object
  if tree found → CHOPPING
  else → stay IDLE (trees depleted, wait for respawn)
```

### Miner (`CCMiningScript`)

**Adapted from:** upstream mining patterns

**States:** `MINING`, `IDLE`

**Behaviors:** `BankingBehavior` (deposit ores), `StuckDetectionBehavior`, `DeathRecoveryBehavior`

**Config options:**
- `rock()` — enum: COPPER, TIN, IRON, COAL, GOLD (name + ore item ID + rock object name + color)
- `action()` — enum: BANK, DROP

**onTick logic:** Identical pattern to Woodcutter — find rock → mine → wait for animation → repeat.

### Fisher (`CCFishingScript`)

**Adapted from:** `AutoFishingScript` (205 LOC → ~100 LOC)

**States:** `FISHING`, `IDLE`

**Behaviors:** `BankingBehavior` (deposit fish), `StuckDetectionBehavior`, `DeathRecoveryBehavior`

**Config options:**
- `fish()` — enum: SHRIMP, TROUT, LOBSTER, SWORDFISH (name + fishing spot NPC IDs + action + required tool)
- `action()` — enum: BANK, DROP

**onTick logic:**
```
FISHING:
  if player is animating → stay FISHING
  find fishing spot NPC matching configured fish type
  if spot found → interact(fishAction) → stay FISHING
  if no spot found → IDLE

IDLE:
  find fishing spot
  if found → FISHING
  else → stay IDLE
```

**Extra:** `hasRequiredItems()` check on startup — warns and shuts down if missing rod/net/bait.

### Cooker (`CCCookingScript`)

**Adapted from:** `AutoCookingScript` (240 LOC → ~100 LOC)

**States:** `COOKING`, `IDLE`

**Behaviors:** `BankingBehavior` (deposit cooked food, withdraw raw food), `StuckDetectionBehavior`, `DeathRecoveryBehavior`

**Config options:**
- `food()` — enum: SHRIMP, TROUT, LOBSTER, SWORDFISH (raw name + cooked name + raw item ID)
- `location()` — enum: RANGE, FIRE (cook action name)

**onTick logic:**
```
COOKING:
  if player is animating → stay COOKING
  if no raw food in inventory → IDLE (triggers banking behavior on next tick)
  find range/fire object → use raw food on it → wait for cooking widget → select cook all

IDLE:
  if raw food in inventory → COOKING
  else → stay IDLE (banking behavior will refill)
```

### F2P Combat Trainer (`CCCombatScript`)

**Adapted from:** AIO Fighter (3000+ LOC → ~200 LOC)

**States:** `FIGHTING`, `IDLE`

**Behaviors:** `EatingBehavior`, `LootingBehavior`, `BuryBonesBehavior`, `StuckDetectionBehavior`, `DeathRecoveryBehavior`

**Config options:**
- `monsterName()` — string: "Chicken", "Cow", "Hill Giant"
- `eatAtPercent()` — int: default 50
- `lootItems()` — string (comma-separated): "Bones,Cowhide,Limpwurt root"
- `buryBones()` — boolean: default true
- `progression()` — boolean: if true, suggests switching monster at combat level thresholds

**onTick logic:**
```
FIGHTING:
  if in combat (interacting with NPC) → stay FIGHTING
  if target died → IDLE

IDLE:
  if progression enabled → check combat level, log suggestion if threshold crossed
  find nearest configured monster (not in combat with another player)
  if found → attack → FIGHTING
  else → stay IDLE
```

**Monster progression thresholds (suggestion only, no auto-switch):**
- Combat < 20: "Consider training on Chickens"
- Combat 20-40: "Consider training on Cows"
- Combat 40+: "Consider training on Hill Giants"

---

## Part 4: Test Strategy

### Architecture

Three test layers, each building on the previous:

```
Layer 3: Contract Tests (parameterized across all scripts)
    ↑ uses
Layer 2: State Machine Tests (per script)
    ↑ uses
Layer 1: Behavior Tests (per behavior)
    ↑ uses
Shared Test Harness: MockGameEnvironment
```

### Shared Test Harness — `MockGameEnvironment`

The reusable foundation. Pre-configured Mockito mocks for all Rs2* utilities with convenience builders.

```java
public class MockGameEnvironment {
    // Pre-configured mocks
    public final Rs2Bank bank;          // mock(Rs2Bank.class)
    public final Rs2Inventory inventory;
    public final Rs2Player player;
    public final Rs2Npc npc;
    public final Rs2GameObject gameObject;
    public final Rs2Walker walker;
    public final Rs2Antiban antiban;
    public final Rs2Equipment equipment;
    public final Rs2GroundItem groundItem;
    public final BotStatusModel statusModel;

    // Convenience builders — configure common scenarios
    public MockGameEnvironment withFullInventory();
    public MockGameEnvironment withInventoryCount(int count);
    public MockGameEnvironment withPlayerAt(WorldPoint point);
    public MockGameEnvironment withPlayerAnimating(boolean animating);
    public MockGameEnvironment withPlayerDead();
    public MockGameEnvironment withHpPercent(int percent);
    public MockGameEnvironment withNearbyNpc(String name, int id);
    public MockGameEnvironment withNearbyObject(String name, int id);
    public MockGameEnvironment withGroundItem(String name, int radius);
    public MockGameEnvironment withInventoryItem(String name);
    public MockGameEnvironment withLoggedIn(boolean loggedIn);

    // Verification helpers
    public void verifyInteracted(String objectName, String action);
    public void verifyBankOpened();
    public void verifyItemDeposited(String name);
    public void verifyWalkedTo(WorldPoint point);
    public void verifyStatusReported(String scriptName, boolean running);
}
```

**Design principle:** Mocks at the Rs2* utility layer (thin mocks), NOT at the RuneLite Client layer. Scripts call Rs2Bank.openBank() → mock returns success/failure. We don't mock the internals of Rs2Bank.

**Static mock setup:** Since Rs2* classes use static methods, the harness uses Mockito's `mockStatic()` to intercept calls. Each test method gets fresh static mock scopes to prevent leakage.

### Layer 1: Behavior Tests

One test class per behavior. Tests the behavior in isolation against MockGameEnvironment.

#### `EatingBehaviorTest`

| Test | Setup | Assertion |
|------|-------|-----------|
| `shouldActivate_whenHpBelowThreshold` | HP at 40%, threshold 50% | `assertTrue(shouldActivate())` |
| `shouldNotActivate_whenHpAboveThreshold` | HP at 60%, threshold 50% | `assertFalse(shouldActivate())` |
| `shouldNotActivate_whenNoFoodInInventory` | HP at 30%, no food | `assertFalse(shouldActivate())` |
| `execute_eatsBestFoodFirst` | Lobster + shrimp in inventory | Verify lobster eaten first |
| `reset_clearsState` | After execution | No lingering state |

#### `BankingBehaviorTest`

| Test | Setup | Assertion |
|------|-------|-----------|
| `shouldActivate_whenInventoryFull` | 28/28 slots | `assertTrue(shouldActivate())` |
| `shouldNotActivate_whenInventoryHasSpace` | 20/28 slots | `assertFalse(shouldActivate())` |
| `execute_depositMatchingItems` | Full of logs, filter=logs | Verify only logs deposited |
| `execute_withdrawsConfiguredItems` | With withdraw config | Verify withdrawal |
| `execute_returnsToActivityLocation` | Activity at (3200, 3200) | Verify walk-back |
| `execute_whenBankFailsToOpen_handles` | Bank open returns false | No crash, retries next tick |

#### `LootingBehaviorTest`

| Test | Setup | Assertion |
|------|-------|-----------|
| `shouldActivate_whenMatchingItemOnGround` | "Bones" within 5 tiles | `assertTrue` |
| `shouldNotActivate_whenNoMatchingItems` | "Bones" config, only "Ashes" on ground | `assertFalse` |
| `shouldNotActivate_whenItemOutsideRadius` | "Bones" at 10 tiles, radius=5 | `assertFalse` |
| `execute_picksUpNearestItem` | Two bone piles | Verify nearest picked up |
| `execute_picksOneItemPerActivation` | Three items on ground | Verify only one picked up |

#### `BuryBonesBehaviorTest`

| Test | Setup | Assertion |
|------|-------|-----------|
| `shouldActivate_whenBonesInInventory` | Has "Bones" | `assertTrue` |
| `shouldNotActivate_whenNoBones` | No bones | `assertFalse` |
| `execute_buriesOneBone` | 5 bones | Verify one "Bury" interaction |

#### `DeathRecoveryBehaviorTest`

| Test | Setup | Assertion |
|------|-------|-----------|
| `shouldActivate_whenDeathScreenVisible` | Death widget visible | `assertTrue` |
| `shouldNotActivate_whenAlive` | Normal play | `assertFalse` |
| `execute_waitsForRespawnThenWalksBack` | Dead, activity at (3200, 3200) | Verify walk after respawn |
| `execute_whenNoActivityLocation_staysAtSpawn` | No location saved | No walk, warning logged |

#### `StuckDetectionBehaviorTest`

| Test | Setup | Assertion |
|------|-------|-----------|
| `shouldActivate_afterTimeout` | Same state 5+ min, no animation | `assertTrue` |
| `shouldNotActivate_whenStateChanging` | State changed 1 min ago | `assertFalse` |
| `shouldNotActivate_whenAnimating` | Same state but player animating | `assertFalse` |

### Layer 2: State Machine Tests

One test class per script. Behaviors are mocked/stubbed — these tests only verify state transition logic.

#### `CCWoodcuttingScriptTest`

| Test | State In | Condition | Expected State | Side Effect |
|------|----------|-----------|----------------|-------------|
| `chopping_whenAnimating_stays` | CHOPPING | Player animating | CHOPPING | No interaction |
| `chopping_whenTreeFound_interacts` | CHOPPING | Tree nearby, not animating | CHOPPING | `interact("Chop down")` |
| `chopping_whenNoTree_goesIdle` | CHOPPING | No tree nearby | IDLE | None |
| `idle_whenTreeAppears_chops` | IDLE | Tree nearby | CHOPPING | `interact("Chop down")` |

#### `CCMiningScriptTest`

Same pattern as Woodcutter (4 tests), substituting rock/mine terminology.

#### `CCFishingScriptTest`

Same pattern (4 tests) + 1 extra:

| Test | State In | Condition | Expected State |
|------|----------|-----------|----------------|
| `run_whenMissingRequiredTool_shutsDown` | — | No fishing rod | Script shuts down |

#### `CCCookingScriptTest`

| Test | State In | Condition | Expected State |
|------|----------|-----------|----------------|
| `cooking_whenAnimating_stays` | COOKING | Animating | COOKING |
| `cooking_whenRawFoodAndRangeFound_cooks` | COOKING | Has raw food, range nearby | COOKING |
| `cooking_whenNoRawFood_goesIdle` | COOKING | No raw food | IDLE |
| `idle_whenRawFoodInInventory_cooks` | IDLE | Has raw food | COOKING |

#### `CCCombatScriptTest`

| Test | State In | Condition | Expected State | Side Effect |
|------|----------|-----------|----------------|-------------|
| `fighting_whenInCombat_stays` | FIGHTING | Interacting with NPC | FIGHTING | None |
| `fighting_whenTargetDied_goesIdle` | FIGHTING | No interaction | IDLE | None |
| `idle_whenMonsterFound_attacks` | IDLE | Monster nearby | FIGHTING | `interact("Attack")` |
| `idle_whenNoMonster_stays` | IDLE | No monster | IDLE | None |
| `idle_progressionEnabled_logsSuggestion` | IDLE | Combat 20, progression on | IDLE | Log suggestion |
| `idle_progressionDisabled_noLog` | IDLE | Combat 20, progression off | IDLE | No log |

### Layer 3: Contract Tests (Parameterized)

One test class that runs against ALL scripts using JUnit `@Parameterized`. Adding a new script = adding one entry to the parameter list.

```java
@RunWith(Parameterized.class)
public class CCScriptContractTest {

    @Parameterized.Parameters(name = "{0}")
    public static Collection<Object[]> scripts() {
        return List.of(
            new Object[]{"CC Woodcutter",      CCWoodcuttingPlugin.class, CCWoodcuttingScript.class},
            new Object[]{"CC Miner",           CCMiningPlugin.class,      CCMiningScript.class},
            new Object[]{"CC Fisher",          CCFishingPlugin.class,     CCFishingScript.class},
            new Object[]{"CC Cooker",          CCCookingPlugin.class,     CCCookingScript.class},
            new Object[]{"CC Combat Trainer",  CCCombatPlugin.class,      CCCombatScript.class}
        );
    }
```

| Test | What it verifies |
|------|------------------|
| `pluginDescriptor_nameStartsWithCC` | `@PluginDescriptor.name()` starts with "CC " |
| `pluginDescriptor_enabledByDefaultIsFalse` | `enabledByDefault = false` |
| `pluginDescriptor_hasCommandCenterTag` | Tags include "commandcenter" |
| `run_callsSetActiveScriptTrue` | `BotStatusModel.setActiveScript(name, true)` called |
| `shutdown_callsSetActiveScriptFalse` | `BotStatusModel.setActiveScript(name, false)` called |
| `shutdown_resetsAllBehaviors` | Every registered behavior's `reset()` called |
| `shutdown_resetsAntibanSettings` | `Rs2Antiban.resetAntibanSettings()` called |

### Test Package Structure

```
src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/
├── core/
│   ├── MockGameEnvironment.java        # Shared harness
│   ├── MockGameEnvironmentTest.java    # Harness self-tests
│   └── behaviors/
│       ├── EatingBehaviorTest.java
│       ├── BankingBehaviorTest.java
│       ├── LootingBehaviorTest.java
│       ├── BuryBonesBehaviorTest.java
│       ├── DeathRecoveryBehaviorTest.java
│       └── StuckDetectionBehaviorTest.java
├── woodcutting/
│   └── CCWoodcuttingScriptTest.java
├── mining/
│   └── CCMiningScriptTest.java
├── fishing/
│   └── CCFishingScriptTest.java
├── cooking/
│   └── CCCookingScriptTest.java
├── combat/
│   └── CCCombatScriptTest.java
└── CCScriptContractTest.java           # Parameterized contract tests
```

### Test Count Summary

| Component | Test Count |
|-----------|-----------|
| MockGameEnvironment (self-tests) | 6 |
| EatingBehavior | 5 |
| BankingBehavior | 6 |
| LootingBehavior | 5 |
| BuryBonesBehavior | 3 |
| DeathRecoveryBehavior | 4 |
| StuckDetectionBehavior | 3 |
| Woodcutter state machine | 4 |
| Miner state machine | 4 |
| Fisher state machine | 5 |
| Cooker state machine | 4 |
| Combat state machine | 6 |
| Contract tests (7 x 5 scripts) | 7 (parameterized) |
| **Total** | **~62** |

---

## Part 5: Overlay Pattern

Each script gets a minimal overlay showing runtime stats. Follows the upstream Microbot overlay pattern.

```java
public class CCWoodcuttingOverlay extends Overlay {
    // Renders:
    // - Script name + version
    // - Current state (CHOPPING / IDLE / BANKING)
    // - Items processed count
    // - Runtime
    // - Items/hour rate
}
```

Overlays are optional for script function but required for debugging during development and user feedback during operation. ~50-80 LOC each.

---

## Part 6: Script Registry Integration

The Dart-side `AppConfigService.scriptRegistry` needs to include the 5 new script names so the launch dialog can offer them. This is a one-line addition per script to the default registry list.

**Names must exactly match `@PluginDescriptor.name()`:**
- `CC Woodcutter`
- `CC Miner`
- `CC Fisher`
- `CC Cooker`
- `CC Combat Trainer`

---

## Part 7: File Inventory

### New Files (Java — Microbot_Frieren)

| File | LOC (est.) | Purpose |
|------|-----------|---------|
| `scripts/core/CCScript.java` | 150 | Base class |
| `scripts/core/CCBehavior.java` | 20 | Behavior interface |
| `scripts/core/behaviors/EatingBehavior.java` | 60 | Eat food |
| `scripts/core/behaviors/BankingBehavior.java` | 100 | Bank cycle |
| `scripts/core/behaviors/BankingConfig.java` | 20 | Banking params |
| `scripts/core/behaviors/LootingBehavior.java` | 60 | Pick up items |
| `scripts/core/behaviors/BuryBonesBehavior.java` | 40 | Bury bones |
| `scripts/core/behaviors/DeathRecoveryBehavior.java` | 60 | Respawn + walk back |
| `scripts/core/behaviors/StuckDetectionBehavior.java` | 70 | Timeout + reset |
| `scripts/woodcutting/CCWoodcuttingPlugin.java` | 40 | Plugin wrapper |
| `scripts/woodcutting/CCWoodcuttingScript.java` | 120 | Script logic |
| `scripts/woodcutting/CCWoodcuttingConfig.java` | 60 | Config |
| `scripts/woodcutting/CCWoodcuttingOverlay.java` | 60 | Overlay |
| `scripts/mining/CCMiningPlugin.java` | 40 | Plugin wrapper |
| `scripts/mining/CCMiningScript.java` | 120 | Script logic |
| `scripts/mining/CCMiningConfig.java` | 60 | Config |
| `scripts/mining/CCMiningOverlay.java` | 60 | Overlay |
| `scripts/fishing/CCFishingPlugin.java` | 40 | Plugin wrapper |
| `scripts/fishing/CCFishingScript.java` | 100 | Script logic |
| `scripts/fishing/CCFishingConfig.java` | 80 | Config |
| `scripts/fishing/CCFishingOverlay.java` | 60 | Overlay |
| `scripts/cooking/CCCookingPlugin.java` | 40 | Plugin wrapper |
| `scripts/cooking/CCCookingScript.java` | 100 | Script logic |
| `scripts/cooking/CCCookingConfig.java` | 70 | Config |
| `scripts/cooking/CCCookingOverlay.java` | 60 | Overlay |
| `scripts/combat/CCCombatPlugin.java` | 40 | Plugin wrapper |
| `scripts/combat/CCCombatScript.java` | 200 | Script logic |
| `scripts/combat/CCCombatConfig.java` | 100 | Config |
| `scripts/combat/CCCombatOverlay.java` | 60 | Overlay |
| **Subtotal (source)** | **~2,040** | |

### New Files (Java — Tests)

| File | LOC (est.) | Purpose |
|------|-----------|---------|
| `core/MockGameEnvironment.java` | 200 | Shared test harness |
| `core/MockGameEnvironmentTest.java` | 60 | Harness self-tests |
| `core/behaviors/EatingBehaviorTest.java` | 80 | |
| `core/behaviors/BankingBehaviorTest.java` | 100 | |
| `core/behaviors/LootingBehaviorTest.java` | 80 | |
| `core/behaviors/BuryBonesBehaviorTest.java` | 50 | |
| `core/behaviors/DeathRecoveryBehaviorTest.java` | 70 | |
| `core/behaviors/StuckDetectionBehaviorTest.java` | 60 | |
| `woodcutting/CCWoodcuttingScriptTest.java` | 70 | |
| `mining/CCMiningScriptTest.java` | 70 | |
| `fishing/CCFishingScriptTest.java` | 80 | |
| `cooking/CCCookingScriptTest.java` | 70 | |
| `combat/CCCombatScriptTest.java` | 100 | |
| `CCScriptContractTest.java` | 80 | Parameterized |
| **Subtotal (tests)** | **~1,170** | |

### Modified Files (Dart — Command Center)

| File | Change |
|------|--------|
| `lib/config/services/app_config_service.dart` | Add 5 script names to default registry |

### Total

- **~2,040 LOC** source (Java)
- **~1,170 LOC** tests (Java)
- **~3,210 LOC** total new code
- **~62 tests**
- **1 LOC** Dart change (script registry)
