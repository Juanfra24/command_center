# Bot Scripts Framework & Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable CC script framework with 6 behaviors and 5 F2P scripts, fully tested with ~60 unit tests.

**Architecture:** Component-based framework where `CCScript<S>` provides lifecycle/status/antiban and delegates cross-cutting concerns to composable `CCBehavior` implementations. Scripts are thin state machines that compose behaviors. Testing uses template-method pattern for testability since Mockito 3.1.0 lacks `mockStatic()`.

**Tech Stack:** Java 11, JUnit 4.12, Mockito 3.1.0, Lombok, RuneLite Plugin API, Microbot Rs2* utilities

**Spec:** `docs/superpowers/specs/2026-03-18-bot-scripts-framework-design.md`

---

## Key Paths

All source under Microbot_Frieren repo at `/mnt/c/Projects/Microbot_Frieren`.

```
SRC  = runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts
TEST = runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts
PKG  = net.runelite.client.plugins.microbot.commandcenter.scripts
```

## Test Approach

Mockito 3.1.0 does NOT support `mockStatic()`. Since Rs2* classes use static methods, behaviors use the **template method pattern** for testability: game queries are extracted into `protected` methods that tests override. This avoids build config changes while keeping tests clean.

```java
// Production: calls Rs2Player
protected int getHpPercent() {
    int max = Rs2Player.getRealSkillLevel(Skill.HITPOINTS);
    return max > 0 ? (100 * Rs2Player.getBoostedSkillLevel(Skill.HITPOINTS) / max) : 100;
}

// Test: overrides with stub
new EatingBehavior(50) { @Override protected int getHpPercent() { return 40; } };
```

## Build & Test Commands

All commands run from `/mnt/c/Projects/Microbot_Frieren`:

```bash
# Compile
./gradlew :runelite-client:compileJava

# Run all CC script tests
./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.*"

# Run a specific test class
./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.EatingBehaviorTest"
```

---

## Chunk 1: Framework Foundation

### Task 1: CCBehavior Interface

**Files:**
- Create: `SRC/core/CCBehavior.java`

- [ ] **Step 1: Create CCBehavior interface**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core;

/**
 * Composable behavior that handles a cross-cutting concern (eating, banking, etc.).
 * Behaviors are checked each tick in priority order. The first to activate handles the tick.
 */
public interface CCBehavior {
    /** Lower number = higher priority. Eating (10) runs before Banking (50). */
    int priority();

    /** Checked every tick. Return true to claim this tick. */
    boolean shouldActivate();

    /** Perform the behavior's action. Only called when shouldActivate() returned true. */
    void execute();

    /** Clean up state on script shutdown. */
    void reset();

    /** Name for logging/debugging. */
    String name();
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:compileJava`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/CCBehavior.java
git commit -m "feat(scripts): add CCBehavior interface"
```

---

### Task 2: CCScript Base Class

**Files:**
- Create: `SRC/core/CCScript.java`

**Context:** Extends Microbot's `Script` class. Manages behaviors, tick loop, Status API reporting, antiban setup. The `onTick()` return value drives state transitions. Behaviors run before `onTick()` each cycle.

- [ ] **Step 1: Create CCScript base class**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core;

import lombok.extern.slf4j.Slf4j;
import net.runelite.api.Skill;
import net.runelite.api.coords.WorldPoint;
import net.runelite.client.config.Config;
import net.runelite.client.plugins.microbot.Microbot;
import net.runelite.client.plugins.microbot.Script;
import net.runelite.client.plugins.microbot.commandcenter.status.BotStatusModel;
import net.runelite.client.plugins.microbot.util.antiban.Rs2Antiban;
import net.runelite.client.plugins.microbot.util.antiban.Rs2AntibanSettings;
import net.runelite.client.plugins.microbot.util.player.Rs2Player;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;

/**
 * Base class for all Command Center scripts. Provides:
 * - Behavior system with priority-based execution
 * - Status API wiring (setActiveScript on start/stop)
 * - Antiban template setup and teardown
 * - Stuck detection timer reset on state change
 *
 * @param <S> State enum type for this script's state machine
 */
@Slf4j
public abstract class CCScript<S extends Enum<S>> extends Script {

    private final List<CCBehavior> behaviors = new ArrayList<>();
    private S currentState;
    private String scriptName;
    private WorldPoint activityLocation;
    private Consumer<Rs2AntibanSettings> antiBanTemplate;
    private long lastStateChangeMs;

    // --- Scripts implement these ---

    /** Register behaviors and set antiban template. Called once before the tick loop starts. */
    protected abstract void configure();

    /** Return the starting state for the state machine. */
    protected abstract S getInitialState();

    /** Main per-tick logic. Return the next state (or same state to stay). */
    protected abstract S onTick(S currentState);

    // --- Framework API for scripts ---

    protected final void registerBehavior(CCBehavior behavior) {
        behaviors.add(behavior);
    }

    protected final void setActivityLocation(WorldPoint point) {
        this.activityLocation = point;
    }

    public final WorldPoint getActivityLocation() {
        return activityLocation;
    }

    protected final void setAntiBanTemplate(Consumer<Rs2AntibanSettings> template) {
        this.antiBanTemplate = template;
    }

    protected final S state() {
        return currentState;
    }

    public final String getScriptName() {
        return scriptName;
    }

    public final long getLastStateChangeMs() {
        return lastStateChangeMs;
    }

    /** Reset to initial state. Used by StuckDetectionBehavior. */
    public final void resetToInitialState() {
        currentState = getInitialState();
        lastStateChangeMs = System.currentTimeMillis();
        log.warn("[{}] Reset to initial state: {}", scriptName, currentState);
    }

    // --- Lifecycle ---

    /**
     * Start the script. Called by the Plugin's startUp().
     * @param config the RuneLite config (passed through, framework is config-agnostic)
     * @param name the @PluginDescriptor name for Status API reporting
     */
    public boolean run(Config config, String name) {
        this.scriptName = name;
        this.currentState = getInitialState();
        this.lastStateChangeMs = System.currentTimeMillis();

        // Configure behaviors and antiban
        configure();
        behaviors.sort(Comparator.comparingInt(CCBehavior::priority));

        // Antiban setup
        Rs2Antiban.resetAntibanSettings();
        if (antiBanTemplate != null) {
            antiBanTemplate.accept(null); // templates are static, param unused
        }

        // Status API
        reportStatus(true);

        // Save initial location
        if (activityLocation == null && Microbot.isLoggedIn()) {
            activityLocation = Rs2Player.getWorldLocation();
        }

        // Tick loop
        mainScheduledFuture = scheduledExecutorService.scheduleWithFixedDelay(() -> {
            try {
                if (!super.run()) return;
                if (!Microbot.isLoggedIn()) return;
                if (Rs2AntibanSettings.actionCooldownActive) return;

                // Run behaviors by priority
                boolean behaviorHandled = false;
                for (CCBehavior behavior : behaviors) {
                    if (behavior.shouldActivate()) {
                        behavior.execute();
                        behaviorHandled = true;
                        break;
                    }
                }

                // If no behavior activated, run script logic
                if (!behaviorHandled) {
                    S nextState = onTick(currentState);
                    if (nextState != currentState) {
                        log.debug("[{}] State: {} -> {}", scriptName, currentState, nextState);
                        currentState = nextState;
                        lastStateChangeMs = System.currentTimeMillis();
                    }
                }
            } catch (Exception e) {
                log.error("[{}] Tick error: {}", scriptName, e.getMessage(), e);
            }
        }, 0, 600, TimeUnit.MILLISECONDS);

        log.info("[{}] Started", scriptName);
        return true;
    }

    @Override
    public void shutdown() {
        // Reset behaviors
        for (CCBehavior behavior : behaviors) {
            try {
                behavior.reset();
            } catch (Exception e) {
                log.warn("[{}] Error resetting behavior {}: {}", scriptName, behavior.name(), e.getMessage());
            }
        }
        behaviors.clear();

        // Antiban reset
        Rs2Antiban.resetAntibanSettings();

        // Status API
        reportStatus(false);

        log.info("[{}] Stopped", scriptName);

        // Parent cleanup (cancels futures, resets walker, etc.)
        super.shutdown();
    }

    // --- Internal helpers ---

    /** Report script status to BotStatusModel if available. */
    private void reportStatus(boolean running) {
        try {
            BotStatusModel statusModel = Microbot.getInjector().getInstance(BotStatusModel.class);
            if (statusModel != null) {
                statusModel.setActiveScript(scriptName, running);
            }
        } catch (Exception e) {
            log.debug("BotStatusModel not available: {}", e.getMessage());
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:compileJava`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/CCScript.java
git commit -m "feat(scripts): add CCScript base class with behavior system and lifecycle"
```

---

### Task 3: EatingBehavior + Tests

**Files:**
- Create: `SRC/core/behaviors/EatingBehavior.java`
- Create: `TEST/core/behaviors/EatingBehaviorTest.java`

- [ ] **Step 1: Write tests first**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import org.junit.Test;
import static org.junit.Assert.*;

public class EatingBehaviorTest {

    private EatingBehavior behaviorWith(int threshold, int hpPercent, boolean hasFood) {
        return new EatingBehavior(threshold) {
            @Override protected int getHpPercent() { return hpPercent; }
            @Override protected boolean hasFood() { return hasFood; }
            @Override public void execute() { /* no-op in test */ }
        };
    }

    @Test
    public void shouldActivate_whenHpBelowThreshold_andHasFood() {
        EatingBehavior b = behaviorWith(50, 40, true);
        assertTrue(b.shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenHpAboveThreshold() {
        EatingBehavior b = behaviorWith(50, 60, true);
        assertFalse(b.shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenNoFood() {
        EatingBehavior b = behaviorWith(50, 30, false);
        assertFalse(b.shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenHpExactlyAtThreshold() {
        EatingBehavior b = behaviorWith(50, 50, true);
        assertFalse(b.shouldActivate());
    }

    @Test
    public void priority_is10() {
        EatingBehavior b = behaviorWith(50, 100, false);
        assertEquals(10, b.priority());
    }
}
```

- [ ] **Step 2: Run tests — verify they fail (class not found)**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.EatingBehaviorTest"`
Expected: FAIL — compilation error, EatingBehavior does not exist

- [ ] **Step 3: Implement EatingBehavior**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import lombok.extern.slf4j.Slf4j;
import net.runelite.api.Skill;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehavior;
import net.runelite.client.plugins.microbot.util.player.Rs2Player;

@Slf4j
public class EatingBehavior implements CCBehavior {

    private final int hpThresholdPercent;

    public EatingBehavior(int hpThresholdPercent) {
        this.hpThresholdPercent = hpThresholdPercent;
    }

    @Override
    public int priority() { return 10; }

    @Override
    public boolean shouldActivate() {
        return getHpPercent() < hpThresholdPercent && hasFood();
    }

    @Override
    public void execute() {
        if (Rs2Player.eatAt(hpThresholdPercent)) {
            log.debug("Ate food at {}% HP", getHpPercent());
        }
    }

    @Override
    public void reset() { /* stateless */ }

    @Override
    public String name() { return "Eating"; }

    // --- Overridable for tests ---

    protected int getHpPercent() {
        int max = Rs2Player.getRealSkillLevel(Skill.HITPOINTS);
        int current = Rs2Player.getBoostedSkillLevel(Skill.HITPOINTS);
        return max > 0 ? (100 * current / max) : 100;
    }

    protected boolean hasFood() {
        return !Rs2Player.getInventoryFood().isEmpty();
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.EatingBehaviorTest"`
Expected: 5 tests PASS

- [ ] **Step 5: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/EatingBehavior.java
git add runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/EatingBehaviorTest.java
git commit -m "feat(scripts): add EatingBehavior with 5 tests"
```

---

### Task 4: BankingBehavior + Tests

**Files:**
- Create: `SRC/core/behaviors/BankingConfig.java`
- Create: `SRC/core/behaviors/BankingBehavior.java`
- Create: `TEST/core/behaviors/BankingBehaviorTest.java`

- [ ] **Step 1: Write tests first**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.api.coords.WorldPoint;
import org.junit.Test;
import static org.junit.Assert.*;

public class BankingBehaviorTest {

    private BankingBehavior behaviorWith(boolean inventoryFull, boolean bankOpen) {
        BankingConfig config = new BankingConfig(
            item -> item.getName().contains("Logs"),
            null, null
        );
        return new BankingBehavior(config, () -> new WorldPoint(3200, 3200, 0)) {
            @Override protected boolean isInventoryFull() { return inventoryFull; }
            @Override protected boolean walkToAndOpenBank() { return bankOpen; }
            @Override protected boolean isBankOpen() { return bankOpen; }
            @Override protected void depositMatchingItems() { }
            @Override protected void withdrawConfiguredItems() { }
            @Override protected void closeBank() { }
            @Override protected void walkToActivityLocation() { }
        };
    }

    @Test
    public void shouldActivate_whenInventoryFull() {
        assertTrue(behaviorWith(true, false).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenInventoryHasSpace() {
        assertFalse(behaviorWith(false, false).shouldActivate());
    }

    @Test
    public void priority_is50() {
        assertEquals(50, behaviorWith(false, false).priority());
    }

    @Test
    public void name_isBanking() {
        assertEquals("Banking", behaviorWith(false, false).name());
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.BankingBehaviorTest"`
Expected: FAIL

- [ ] **Step 3: Create BankingConfig**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.client.plugins.microbot.util.inventory.Rs2ItemModel;

import java.util.List;
import java.util.function.Predicate;

public class BankingConfig {
    public final Predicate<Rs2ItemModel> depositFilter;
    public final List<String> withdrawItems;
    public final Integer withdrawQuantity;

    public BankingConfig(Predicate<Rs2ItemModel> depositFilter, List<String> withdrawItems, Integer withdrawQuantity) {
        this.depositFilter = depositFilter;
        this.withdrawItems = withdrawItems;
        this.withdrawQuantity = withdrawQuantity;
    }
}
```

- [ ] **Step 4: Implement BankingBehavior**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import lombok.extern.slf4j.Slf4j;
import net.runelite.api.coords.WorldPoint;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehavior;
import net.runelite.client.plugins.microbot.util.bank.Rs2Bank;
import net.runelite.client.plugins.microbot.util.inventory.Rs2Inventory;
import net.runelite.client.plugins.microbot.util.walker.Rs2Walker;

import java.util.function.Supplier;

@Slf4j
public class BankingBehavior implements CCBehavior {

    private final BankingConfig config;
    private final Supplier<WorldPoint> activityLocationSupplier;

    public BankingBehavior(BankingConfig config, Supplier<WorldPoint> activityLocationSupplier) {
        this.config = config;
        this.activityLocationSupplier = activityLocationSupplier;
    }

    @Override public int priority() { return 50; }
    @Override public String name() { return "Banking"; }

    @Override
    public boolean shouldActivate() {
        return isInventoryFull();
    }

    @Override
    public void execute() {
        if (!walkToAndOpenBank()) return;
        if (!isBankOpen()) return;

        depositMatchingItems();
        withdrawConfiguredItems();
        closeBank();
        walkToActivityLocation();

        log.debug("Banking cycle complete");
    }

    @Override
    public void reset() { /* stateless */ }

    // --- Overridable for tests ---

    protected boolean isInventoryFull() {
        return Rs2Inventory.isFull();
    }

    protected boolean walkToAndOpenBank() {
        return Rs2Bank.walkToBankAndUseBank();
    }

    protected boolean isBankOpen() {
        return Rs2Bank.isOpen();
    }

    protected void depositMatchingItems() {
        if (config.depositFilter != null) {
            Rs2Bank.depositAll(config.depositFilter);
        } else {
            Rs2Bank.depositAll();
        }
    }

    protected void withdrawConfiguredItems() {
        if (config.withdrawItems != null) {
            for (String item : config.withdrawItems) {
                if (config.withdrawQuantity != null) {
                    Rs2Bank.withdrawItem(true, item);
                } else {
                    Rs2Bank.withdrawAll(item);
                }
            }
        }
    }

    protected void closeBank() {
        Rs2Bank.closeBank();
    }

    protected void walkToActivityLocation() {
        WorldPoint loc = activityLocationSupplier.get();
        if (loc != null) {
            Rs2Walker.walkTo(loc);
        }
    }
}
```

- [ ] **Step 5: Run tests — verify they pass**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.BankingBehaviorTest"`
Expected: 4 tests PASS

- [ ] **Step 6: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/BankingConfig.java
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/BankingBehavior.java
git add runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/BankingBehaviorTest.java
git commit -m "feat(scripts): add BankingBehavior + BankingConfig with 4 tests"
```

---

### Task 5: LootingBehavior + Tests

**Files:**
- Create: `SRC/core/behaviors/LootingBehavior.java`
- Create: `TEST/core/behaviors/LootingBehaviorTest.java`

- [ ] **Step 1: Write tests first**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import org.junit.Test;
import java.util.List;
import static org.junit.Assert.*;

public class LootingBehaviorTest {

    private LootingBehavior behaviorWith(List<String> itemNames, int radius, boolean matchingItemOnGround) {
        return new LootingBehavior(itemNames, radius) {
            @Override protected boolean hasMatchingGroundItem() { return matchingItemOnGround; }
            @Override public void execute() { /* no-op in test */ }
        };
    }

    @Test
    public void shouldActivate_whenMatchingItemOnGround() {
        assertTrue(behaviorWith(List.of("Bones"), 5, true).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenNoMatchingItems() {
        assertFalse(behaviorWith(List.of("Bones"), 5, false).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenEmptyItemList() {
        assertFalse(behaviorWith(List.of(), 5, false).shouldActivate());
    }

    @Test
    public void priority_is40() {
        assertEquals(40, behaviorWith(List.of("Bones"), 5, false).priority());
    }

    @Test
    public void name_isLooting() {
        assertEquals("Looting", behaviorWith(List.of(), 5, false).name());
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.LootingBehaviorTest"`
Expected: FAIL

- [ ] **Step 3: Implement LootingBehavior**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import lombok.extern.slf4j.Slf4j;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehavior;
import net.runelite.client.plugins.microbot.util.grounditem.LootingParameters;
import net.runelite.client.plugins.microbot.util.grounditem.Rs2GroundItem;

import java.util.List;

@Slf4j
public class LootingBehavior implements CCBehavior {

    private final List<String> itemNames;
    private final int radius;

    public LootingBehavior(List<String> itemNames, int radius) {
        this.itemNames = itemNames;
        this.radius = radius;
    }

    @Override public int priority() { return 40; }
    @Override public String name() { return "Looting"; }

    @Override
    public boolean shouldActivate() {
        return !itemNames.isEmpty() && hasMatchingGroundItem();
    }

    @Override
    public void execute() {
        LootingParameters params = new LootingParameters(
            radius, 1, 1, 1,
            false, false,
            itemNames.toArray(new String[0])
        );
        if (Rs2GroundItem.lootItemsBasedOnNames(params)) {
            log.debug("Looted item");
        }
    }

    @Override
    public void reset() { /* stateless */ }

    // --- Overridable for tests ---

    protected boolean hasMatchingGroundItem() {
        LootingParameters params = new LootingParameters(
            radius, 1, 1, 1,
            false, false,
            itemNames.toArray(new String[0])
        );
        RS2Item[] items = Rs2GroundItem.getAll(radius);
        if (items == null) return false;
        for (RS2Item item : items) {
            for (String name : itemNames) {
                if (item.getItem().getName() != null &&
                    item.getItem().getName().equalsIgnoreCase(name)) {
                    return true;
                }
            }
        }
        return false;
    }
}
```

**Note to implementer:** The `hasMatchingGroundItem()` implementation depends on the exact Rs2GroundItem API. Adapt the ground item detection to what's actually available — the key is that the method is `protected` and overridable so tests can stub it. Check `Rs2GroundItem.getAll()` return type and adjust accordingly.

- [ ] **Step 4: Run tests — verify they pass**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.LootingBehaviorTest"`
Expected: 5 tests PASS

- [ ] **Step 5: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/LootingBehavior.java
git add runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/LootingBehaviorTest.java
git commit -m "feat(scripts): add LootingBehavior with 5 tests"
```

---

## Chunk 2: Remaining Behaviors

### Task 6: BuryBonesBehavior + Tests

**Files:**
- Create: `SRC/core/behaviors/BuryBonesBehavior.java`
- Create: `TEST/core/behaviors/BuryBonesBehaviorTest.java`

- [ ] **Step 1: Write tests first**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import org.junit.Test;
import static org.junit.Assert.*;

public class BuryBonesBehaviorTest {

    private BuryBonesBehavior behaviorWith(boolean hasBones, boolean inCombat) {
        return new BuryBonesBehavior() {
            @Override protected boolean hasBones() { return hasBones; }
            @Override protected boolean isInCombat() { return inCombat; }
            @Override public void execute() { /* no-op */ }
        };
    }

    @Test
    public void shouldActivate_whenHasBones_andNotInCombat() {
        assertTrue(behaviorWith(true, false).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenNoBones() {
        assertFalse(behaviorWith(false, false).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenInCombat() {
        assertFalse(behaviorWith(true, true).shouldActivate());
    }
}
```

- [ ] **Step 2: Implement BuryBonesBehavior**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import lombok.extern.slf4j.Slf4j;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehavior;
import net.runelite.client.plugins.microbot.util.inventory.Rs2Inventory;
import net.runelite.client.plugins.microbot.util.player.Rs2Player;

@Slf4j
public class BuryBonesBehavior implements CCBehavior {

    @Override public int priority() { return 45; }
    @Override public String name() { return "BuryBones"; }

    @Override
    public boolean shouldActivate() {
        return hasBones() && !isInCombat();
    }

    @Override
    public void execute() {
        if (Rs2Inventory.interact("Bones", "Bury")) {
            log.debug("Buried bones");
        }
    }

    @Override
    public void reset() { /* stateless */ }

    protected boolean hasBones() {
        return Rs2Inventory.contains("Bones");
    }

    protected boolean isInCombat() {
        return Rs2Player.isInCombat();
    }
}
```

- [ ] **Step 3: Run tests — verify they pass**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.BuryBonesBehaviorTest"`
Expected: 3 tests PASS

- [ ] **Step 4: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/BuryBonesBehavior.java
git add runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/BuryBonesBehaviorTest.java
git commit -m "feat(scripts): add BuryBonesBehavior with 3 tests"
```

---

### Task 7: DeathRecoveryBehavior + Tests

**Files:**
- Create: `SRC/core/behaviors/DeathRecoveryBehavior.java`
- Create: `TEST/core/behaviors/DeathRecoveryBehaviorTest.java`

- [ ] **Step 1: Write tests first**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.api.coords.WorldPoint;
import org.junit.Test;
import static org.junit.Assert.*;

public class DeathRecoveryBehaviorTest {

    private DeathRecoveryBehavior behaviorWith(boolean isDead, WorldPoint activityLocation) {
        return new DeathRecoveryBehavior(() -> activityLocation) {
            @Override protected boolean isPlayerDead() { return isDead; }
            @Override public void execute() { /* no-op */ }
        };
    }

    @Test
    public void shouldActivate_whenPlayerDead() {
        assertTrue(behaviorWith(true, new WorldPoint(3200, 3200, 0)).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenAlive() {
        assertFalse(behaviorWith(false, new WorldPoint(3200, 3200, 0)).shouldActivate());
    }

    @Test
    public void priority_is5() {
        assertEquals(5, behaviorWith(false, null).priority());
    }

    @Test
    public void name_isDeathRecovery() {
        assertEquals("DeathRecovery", behaviorWith(false, null).name());
    }
}
```

- [ ] **Step 2: Implement DeathRecoveryBehavior**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import lombok.extern.slf4j.Slf4j;
import net.runelite.api.coords.WorldPoint;
import net.runelite.client.plugins.microbot.Microbot;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehavior;
import net.runelite.client.plugins.microbot.util.player.Rs2Player;
import net.runelite.client.plugins.microbot.util.walker.Rs2Walker;

import java.util.function.Supplier;

import static net.runelite.client.plugins.microbot.util.Global.sleep;
import static net.runelite.client.plugins.microbot.util.Global.sleepUntil;

@Slf4j
public class DeathRecoveryBehavior implements CCBehavior {

    private static final int DEATH_VARP = 4517;
    private static final int DEATH_REGION = 12633;

    private final Supplier<WorldPoint> activityLocationSupplier;

    public DeathRecoveryBehavior(Supplier<WorldPoint> activityLocationSupplier) {
        this.activityLocationSupplier = activityLocationSupplier;
    }

    @Override public int priority() { return 5; }
    @Override public String name() { return "DeathRecovery"; }

    @Override
    public boolean shouldActivate() {
        return isPlayerDead();
    }

    @Override
    public void execute() {
        log.info("Death detected — recovering");
        // Wait for respawn
        sleepUntil(() -> !isPlayerDead(), 15000);
        sleep(2000, 3000);

        // Walk back to activity location
        WorldPoint loc = activityLocationSupplier.get();
        if (loc != null) {
            Rs2Walker.walkTo(loc);
            log.info("Walking back to activity location: {}", loc);
        } else {
            log.warn("No activity location saved — staying at spawn");
        }
    }

    @Override
    public void reset() { /* stateless */ }

    protected boolean isPlayerDead() {
        try {
            return Microbot.getVarbitPlayerValue(DEATH_VARP) == 1
                && Rs2Player.getWorldLocation() != null
                && Rs2Player.getWorldLocation().getRegionID() == DEATH_REGION;
        } catch (Exception e) {
            return false;
        }
    }
}
```

- [ ] **Step 3: Run tests — verify they pass**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.DeathRecoveryBehaviorTest"`
Expected: 4 tests PASS

- [ ] **Step 4: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/DeathRecoveryBehavior.java
git add runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/DeathRecoveryBehaviorTest.java
git commit -m "feat(scripts): add DeathRecoveryBehavior with 4 tests"
```

---

### Task 8: StuckDetectionBehavior + Tests

**Files:**
- Create: `SRC/core/behaviors/StuckDetectionBehavior.java`
- Create: `TEST/core/behaviors/StuckDetectionBehaviorTest.java`

- [ ] **Step 1: Write tests first**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import org.junit.Test;
import static org.junit.Assert.*;

public class StuckDetectionBehaviorTest {

    private StuckDetectionBehavior behaviorWith(long timeoutMs, long timeSinceLastChange, boolean isAnimating) {
        return new StuckDetectionBehavior(timeoutMs) {
            @Override protected long getTimeSinceLastStateChangeMs() { return timeSinceLastChange; }
            @Override protected boolean isPlayerActive() { return isAnimating; }
            @Override public void execute() { /* no-op */ }
        };
    }

    @Test
    public void shouldActivate_afterTimeout_whenInactive() {
        // 5 min timeout, 6 min since last change, not animating
        assertTrue(behaviorWith(300_000, 360_000, false).shouldActivate());
    }

    @Test
    public void shouldNotActivate_beforeTimeout() {
        // 5 min timeout, 1 min since last change
        assertFalse(behaviorWith(300_000, 60_000, false).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenAnimating_evenAfterTimeout() {
        // 5 min timeout, 6 min since last change, but animating
        assertFalse(behaviorWith(300_000, 360_000, true).shouldActivate());
    }
}
```

- [ ] **Step 2: Implement StuckDetectionBehavior**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import lombok.extern.slf4j.Slf4j;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehavior;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCScript;
import net.runelite.client.plugins.microbot.util.player.Rs2Player;

@Slf4j
public class StuckDetectionBehavior implements CCBehavior {

    private static final long DEFAULT_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes

    private final long timeoutMs;
    private CCScript<?> script;

    public StuckDetectionBehavior() {
        this(DEFAULT_TIMEOUT_MS);
    }

    public StuckDetectionBehavior(long timeoutMs) {
        this.timeoutMs = timeoutMs;
    }

    /** Must be called after script is available. */
    public void setScript(CCScript<?> script) {
        this.script = script;
    }

    @Override public int priority() { return 1; }
    @Override public String name() { return "StuckDetection"; }

    @Override
    public boolean shouldActivate() {
        return getTimeSinceLastStateChangeMs() > timeoutMs && !isPlayerActive();
    }

    @Override
    public void execute() {
        log.warn("Stuck detected after {}ms — resetting to initial state", timeoutMs);
        if (script != null) {
            script.resetToInitialState();
        }
    }

    @Override
    public void reset() { /* stateless */ }

    protected long getTimeSinceLastStateChangeMs() {
        if (script == null) return 0;
        return System.currentTimeMillis() - script.getLastStateChangeMs();
    }

    protected boolean isPlayerActive() {
        return Rs2Player.isAnimating() || Rs2Player.isMoving();
    }
}
```

- [ ] **Step 3: Run tests — verify they pass**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.StuckDetectionBehaviorTest"`
Expected: 3 tests PASS

- [ ] **Step 4: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/StuckDetectionBehavior.java
git add runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/core/behaviors/StuckDetectionBehaviorTest.java
git commit -m "feat(scripts): add StuckDetectionBehavior with 3 tests"
```

---

## Chunk 3: Scripts

Each script follows the same 4-file pattern: Plugin, Script, Config, Overlay. The Woodcutter is shown in full detail as the template. Subsequent scripts follow the same pattern with their specific state machine and config.

### Task 9: CC Woodcutter (template script)

**Files:**
- Create: `SRC/woodcutting/WoodcuttingTree.java` (enum)
- Create: `SRC/woodcutting/CCWoodcuttingConfig.java`
- Create: `SRC/woodcutting/CCWoodcuttingScript.java`
- Create: `SRC/woodcutting/CCWoodcuttingPlugin.java`
- Create: `SRC/woodcutting/CCWoodcuttingOverlay.java`
- Create: `TEST/woodcutting/CCWoodcuttingScriptTest.java`

**Context:** Recovered from upstream `AutoWoodcuttingScript` (519 LOC → ~120 LOC). Two states: CHOPPING and IDLE. BankingBehavior handles inventory-full. Antiban uses woodcutting template.

- [ ] **Step 1: Write script tests first**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting;

import org.junit.Test;
import static org.junit.Assert.*;

public class CCWoodcuttingScriptTest {

    enum Action { BANK, DROP }

    private CCWoodcuttingScript scriptWith(boolean playerBusy, boolean treeFound) {
        return new CCWoodcuttingScript() {
            @Override protected boolean isPlayerBusy() { return playerBusy; }
            @Override protected boolean findAndChopTree() { return treeFound; }
            @Override protected void dropAllLogs() { }
        };
    }

    @Test
    public void chopping_whenAnimating_stays() {
        CCWoodcuttingScript s = scriptWith(true, false);
        assertEquals(CCWoodcuttingScript.State.CHOPPING,
            s.onTick(CCWoodcuttingScript.State.CHOPPING));
    }

    @Test
    public void chopping_whenTreeFound_stays() {
        CCWoodcuttingScript s = scriptWith(false, true);
        assertEquals(CCWoodcuttingScript.State.CHOPPING,
            s.onTick(CCWoodcuttingScript.State.CHOPPING));
    }

    @Test
    public void chopping_whenNoTree_goesIdle() {
        CCWoodcuttingScript s = scriptWith(false, false);
        assertEquals(CCWoodcuttingScript.State.IDLE,
            s.onTick(CCWoodcuttingScript.State.CHOPPING));
    }

    @Test
    public void idle_whenTreeFound_chops() {
        CCWoodcuttingScript s = scriptWith(false, true);
        assertEquals(CCWoodcuttingScript.State.CHOPPING,
            s.onTick(CCWoodcuttingScript.State.IDLE));
    }
}
```

- [ ] **Step 2: Create WoodcuttingTree enum**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum WoodcuttingTree {
    TREE("Tree", "Logs", "Chop down"),
    OAK("Oak", "Oak logs", "Chop down"),
    WILLOW("Willow", "Willow logs", "Chop down"),
    MAPLE("Maple tree", "Maple logs", "Chop down"),
    YEW("Yew", "Yew logs", "Chop down");

    private final String objectName;
    private final String logName;
    private final String action;
}
```

- [ ] **Step 3: Create CCWoodcuttingConfig**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting;

import net.runelite.client.config.Config;
import net.runelite.client.config.ConfigGroup;
import net.runelite.client.config.ConfigItem;
import net.runelite.client.config.ConfigSection;

@ConfigGroup("ccwoodcutting")
public interface CCWoodcuttingConfig extends Config {

    @ConfigSection(name = "General", position = 0)
    String generalSection = "general";

    @ConfigItem(keyName = "tree", name = "Tree Type", description = "Which tree to chop",
        position = 0, section = generalSection)
    default WoodcuttingTree tree() { return WoodcuttingTree.TREE; }

    @ConfigItem(keyName = "bankLogs", name = "Bank Logs", description = "Bank logs instead of dropping",
        position = 1, section = generalSection)
    default boolean bankLogs() { return true; }
}
```

- [ ] **Step 4: Implement CCWoodcuttingScript**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting;

import lombok.extern.slf4j.Slf4j;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCScript;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.BankingBehavior;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.BankingConfig;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.DeathRecoveryBehavior;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.StuckDetectionBehavior;
import net.runelite.client.plugins.microbot.util.antiban.Rs2Antiban;
import net.runelite.client.plugins.microbot.util.gameobject.Rs2GameObject;
import net.runelite.client.plugins.microbot.util.inventory.Rs2Inventory;
import net.runelite.client.plugins.microbot.util.player.Rs2Player;

import javax.inject.Inject;

@Slf4j
public class CCWoodcuttingScript extends CCScript<CCWoodcuttingScript.State> {

    public enum State { CHOPPING, IDLE }

    @Inject private CCWoodcuttingConfig config;

    @Override
    protected void configure() {
        if (config != null && config.bankLogs()) {
            BankingConfig bankConfig = new BankingConfig(
                item -> item.getName().toLowerCase().contains("logs"),
                null, null
            );
            registerBehavior(new BankingBehavior(bankConfig, this::getActivityLocation));
        }
        registerBehavior(new DeathRecoveryBehavior(this::getActivityLocation));
        StuckDetectionBehavior stuck = new StuckDetectionBehavior();
        stuck.setScript(this);
        registerBehavior(stuck);

        setAntiBanTemplate(s -> Rs2Antiban.antibanSetupTemplates.applyWoodcuttingSetup());
    }

    @Override
    protected State getInitialState() { return State.CHOPPING; }

    @Override
    protected State onTick(State currentState) {
        switch (currentState) {
            case CHOPPING:
                if (isPlayerBusy()) return State.CHOPPING;
                if (!config.bankLogs() && Rs2Inventory.isFull()) {
                    dropAllLogs();
                    return State.CHOPPING;
                }
                if (findAndChopTree()) return State.CHOPPING;
                return State.IDLE;

            case IDLE:
                if (findAndChopTree()) return State.CHOPPING;
                return State.IDLE;

            default:
                return State.IDLE;
        }
    }

    // --- Overridable for tests ---

    protected boolean isPlayerBusy() {
        return Rs2Player.isAnimating() || Rs2Player.isMoving();
    }

    protected boolean findAndChopTree() {
        if (config == null) return false;
        WoodcuttingTree tree = config.tree();
        return Rs2GameObject.interact(tree.getObjectName(), tree.getAction());
    }

    protected void dropAllLogs() {
        if (config != null) {
            Rs2Inventory.dropAll(item ->
                item.getName().toLowerCase().contains("logs"));
        }
    }
}
```

- [ ] **Step 5: Create CCWoodcuttingPlugin**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting;

import lombok.extern.slf4j.Slf4j;
import net.runelite.client.plugins.Plugin;
import net.runelite.client.plugins.PluginDescriptor;
import net.runelite.client.ui.overlay.OverlayManager;

import javax.inject.Inject;

@PluginDescriptor(
    name = "CC Woodcutter",
    description = "Chop trees, bank or drop logs",
    tags = {"microbot", "woodcutting", "f2p", "commandcenter"},
    enabledByDefault = false
)
@Slf4j
public class CCWoodcuttingPlugin extends Plugin {
    @Inject private CCWoodcuttingScript script;
    @Inject private CCWoodcuttingConfig config;
    @Inject private OverlayManager overlayManager;
    @Inject private CCWoodcuttingOverlay overlay;

    @Override
    protected void startUp() {
        overlayManager.add(overlay);
        script.run(config, "CC Woodcutter");
    }

    @Override
    protected void shutDown() {
        script.shutdown();
        overlayManager.remove(overlay);
    }
}
```

- [ ] **Step 6: Create CCWoodcuttingOverlay**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting;

import net.runelite.client.plugins.microbot.Microbot;
import net.runelite.client.ui.overlay.Overlay;
import net.runelite.client.ui.overlay.OverlayPanel;
import net.runelite.client.ui.overlay.OverlayPosition;
import net.runelite.client.ui.overlay.components.LineComponent;
import net.runelite.client.ui.overlay.components.TitleComponent;

import javax.inject.Inject;
import java.awt.*;

public class CCWoodcuttingOverlay extends OverlayPanel {
    private final CCWoodcuttingScript script;

    @Inject
    public CCWoodcuttingOverlay(CCWoodcuttingScript script) {
        this.script = script;
        setPosition(OverlayPosition.TOP_LEFT);
        setNaughty();
    }

    @Override
    public Dimension render(Graphics2D graphics) {
        if (!Microbot.isLoggedIn() || !script.isRunning()) return null;

        panelComponent.getChildren().add(TitleComponent.builder()
            .text("CC Woodcutter")
            .color(Color.GREEN)
            .build());
        panelComponent.getChildren().add(LineComponent.builder()
            .left("State:")
            .right(script.state() != null ? script.state().name() : "—")
            .build());

        return super.render(graphics);
    }
}
```

- [ ] **Step 7: Run tests — verify they pass**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting.CCWoodcuttingScriptTest"`
Expected: 4 tests PASS

- [ ] **Step 8: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts/woodcutting/
git add runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/woodcutting/
git commit -m "feat(scripts): add CC Woodcutter — plugin, script, config, overlay, 4 tests"
```

---

### Task 10: CC Miner

**Files:**
- Create: `SRC/mining/MiningRock.java` (enum: COPPER, TIN, IRON, COAL, GOLD — objectName, oreName, action)
- Create: `SRC/mining/CCMiningConfig.java` (rock type, bank vs drop)
- Create: `SRC/mining/CCMiningScript.java` (States: MINING, IDLE — identical pattern to Woodcutter)
- Create: `SRC/mining/CCMiningPlugin.java` (descriptor: "CC Miner")
- Create: `SRC/mining/CCMiningOverlay.java`
- Create: `TEST/mining/CCMiningScriptTest.java` (4 tests: same transitions as Woodcutter)

Follow the exact same pattern as Task 9, substituting:
- `WoodcuttingTree` → `MiningRock`
- `Rs2GameObject.interact(rock.getObjectName(), "Mine")` for interaction
- `Rs2Antiban.antibanSetupTemplates.applyMiningSetup()` for antiban
- States: `MINING`, `IDLE`
- `isPlayerBusy()` checks `Rs2Player.isAnimating() || Rs2Player.isMoving()`

- [ ] **Step 1:** Write 4 tests (mining_whenAnimating_stays, mining_whenRockFound_stays, mining_whenNoRock_goesIdle, idle_whenRockFound_mines)
- [ ] **Step 2:** Run tests — verify they fail
- [ ] **Step 3:** Implement all 5 source files following Woodcutter pattern
- [ ] **Step 4:** Run tests — verify they pass
- [ ] **Step 5:** Commit: `feat(scripts): add CC Miner — plugin, script, config, overlay, 4 tests`

---

### Task 11: CC Fisher

**Files:**
- Create: `SRC/fishing/FishType.java` (enum: SHRIMP, TROUT, LOBSTER, SWORDFISH — npcIds, action, requiredTool)
- Create: `SRC/fishing/CCFishingConfig.java` (fish type, bank vs drop)
- Create: `SRC/fishing/CCFishingScript.java` (States: FISHING, IDLE)
- Create: `SRC/fishing/CCFishingPlugin.java` (descriptor: "CC Fisher")
- Create: `SRC/fishing/CCFishingOverlay.java`
- Create: `TEST/fishing/CCFishingScriptTest.java` (5 tests)

Key differences from Woodcutter:
- Uses `Rs2Npc.interact()` instead of `Rs2GameObject.interact()` (fishing spots are NPCs)
- `FishType` enum stores NPC IDs + interaction action (e.g., "Net", "Lure", "Cage", "Harpoon")
- Has a `hasRequiredItems()` check that shuts down if missing required tool
- `Rs2Antiban.antibanSetupTemplates.applyFishingSetup()` for antiban

**Extra test:**
```java
@Test
public void run_whenMissingRequiredTool_shutsDown() {
    CCFishingScript s = new CCFishingScript() {
        @Override protected boolean hasRequiredTool() { return false; }
    };
    // Verify configure() or first onTick handles missing tool gracefully
}
```

- [ ] **Step 1:** Write 5 tests
- [ ] **Step 2:** Run tests — verify they fail
- [ ] **Step 3:** Implement all 5 source files
- [ ] **Step 4:** Run tests — verify they pass
- [ ] **Step 5:** Commit: `feat(scripts): add CC Fisher — plugin, script, config, overlay, 5 tests`

---

### Task 12: CC Cooker

**Files:**
- Create: `SRC/cooking/CookableFood.java` (enum: SHRIMP, TROUT, LOBSTER, SWORDFISH — rawName, cookedName, rawItemId)
- Create: `SRC/cooking/CCCookingConfig.java` (food type, cook on range vs fire)
- Create: `SRC/cooking/CCCookingScript.java` (States: COOKING, IDLE)
- Create: `SRC/cooking/CCCookingPlugin.java` (descriptor: "CC Cooker")
- Create: `SRC/cooking/CCCookingOverlay.java`
- Create: `TEST/cooking/CCCookingScriptTest.java` (4 tests)

Key differences from gathering scripts:
- Uses `Rs2Inventory.useItemOnObject()` or equivalent — use raw food on range/fire
- Banking behavior BOTH deposits cooked food AND withdraws raw food
- The BankingConfig has `withdrawItems = [rawFoodName]`
- `Rs2Antiban.antibanSetupTemplates.applyCookingSetup()` for antiban

State machine:
```
COOKING: if animating → stay. if no raw food → IDLE. else find range, use food on it → stay.
IDLE: if has raw food → COOKING. else stay (banking refills).
```

- [ ] **Step 1:** Write 4 tests
- [ ] **Step 2:** Run tests — verify they fail
- [ ] **Step 3:** Implement all 5 source files
- [ ] **Step 4:** Run tests — verify they pass
- [ ] **Step 5:** Commit: `feat(scripts): add CC Cooker — plugin, script, config, overlay, 4 tests`

---

### Task 13: CC Combat Trainer

**Files:**
- Create: `SRC/combat/CCCombatConfig.java` (monster name, eat%, loot items, bury bones, progression)
- Create: `SRC/combat/CCCombatScript.java` (States: FIGHTING, IDLE)
- Create: `SRC/combat/CCCombatPlugin.java` (descriptor: "CC Combat Trainer")
- Create: `SRC/combat/CCCombatOverlay.java`
- Create: `TEST/combat/CCCombatScriptTest.java` (6 tests)

Key differences from gathering scripts:
- Uses `Rs2Npc.interact(monsterName, "Attack")` for interaction
- Registers `EatingBehavior`, `LootingBehavior`, `BuryBonesBehavior` in addition to standard ones
- Monster progression: if `config.progression()` is true, log suggestions at combat level thresholds
- `Rs2Antiban.antibanSetupTemplates.applyCombatSetup()` for antiban
- `findAndAttackMonster()` must filter out NPCs already in combat with another player

State machine:
```
FIGHTING: if player is interacting with NPC → stay. else → IDLE (target died or lost).
IDLE: check progression suggestion. find monster → attack → FIGHTING. no monster → stay.
```

Tests:
```java
fighting_whenInCombat_stays()
fighting_whenTargetDied_goesIdle()
idle_whenMonsterFound_attacks()
idle_whenNoMonster_stays()
idle_progressionEnabled_logsSuggestion()
idle_progressionDisabled_noLog()
```

- [ ] **Step 1:** Write 6 tests
- [ ] **Step 2:** Run tests — verify they fail
- [ ] **Step 3:** Implement all 4 source files
- [ ] **Step 4:** Run tests — verify they pass
- [ ] **Step 5:** Commit: `feat(scripts): add CC Combat Trainer — plugin, script, config, overlay, 6 tests`

---

## Chunk 4: Contract Tests + Integration

### Task 14: Parameterized Contract Tests

**Files:**
- Create: `TEST/CCScriptContractTest.java`

These tests run against ALL 5 script plugins via reflection. Validates naming conventions, `enabledByDefault`, and tag requirements. Adding future scripts means adding one line to the parameters list.

- [ ] **Step 1: Write parameterized contract tests**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts;

import net.runelite.client.plugins.PluginDescriptor;
import net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting.CCWoodcuttingPlugin;
import net.runelite.client.plugins.microbot.commandcenter.scripts.mining.CCMiningPlugin;
import net.runelite.client.plugins.microbot.commandcenter.scripts.fishing.CCFishingPlugin;
import net.runelite.client.plugins.microbot.commandcenter.scripts.cooking.CCCookingPlugin;
import net.runelite.client.plugins.microbot.commandcenter.scripts.combat.CCCombatPlugin;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;

import java.util.Arrays;
import java.util.Collection;

import static org.junit.Assert.*;

@RunWith(Parameterized.class)
public class CCScriptContractTest {

    @Parameterized.Parameters(name = "{0}")
    public static Collection<Object[]> scripts() {
        return Arrays.asList(new Object[][]{
            {"CC Woodcutter", CCWoodcuttingPlugin.class},
            {"CC Miner", CCMiningPlugin.class},
            {"CC Fisher", CCFishingPlugin.class},
            {"CC Cooker", CCCookingPlugin.class},
            {"CC Combat Trainer", CCCombatPlugin.class},
        });
    }

    private final String expectedName;
    private final Class<?> pluginClass;

    public CCScriptContractTest(String expectedName, Class<?> pluginClass) {
        this.expectedName = expectedName;
        this.pluginClass = pluginClass;
    }

    private PluginDescriptor getDescriptor() {
        return pluginClass.getAnnotation(PluginDescriptor.class);
    }

    @Test
    public void pluginDescriptor_exists() {
        assertNotNull("Missing @PluginDescriptor on " + pluginClass.getSimpleName(),
            getDescriptor());
    }

    @Test
    public void pluginDescriptor_nameStartsWithCC() {
        assertTrue("Name should start with 'CC ': " + getDescriptor().name(),
            getDescriptor().name().startsWith("CC "));
    }

    @Test
    public void pluginDescriptor_nameMatchesExpected() {
        assertEquals(expectedName, getDescriptor().name());
    }

    @Test
    public void pluginDescriptor_enabledByDefaultIsFalse() {
        assertFalse("enabledByDefault should be false",
            getDescriptor().enabledByDefault());
    }

    @Test
    public void pluginDescriptor_hasCommandCenterTag() {
        assertTrue("Tags should include 'commandcenter'",
            Arrays.asList(getDescriptor().tags()).contains("commandcenter"));
    }

    @Test
    public void pluginDescriptor_hasMicrobotTag() {
        assertTrue("Tags should include 'microbot'",
            Arrays.asList(getDescriptor().tags()).contains("microbot"));
    }
}
```

- [ ] **Step 2: Run contract tests**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.CCScriptContractTest"`
Expected: 30 tests PASS (6 tests × 5 scripts)

- [ ] **Step 3: Commit**

```bash
cd /mnt/c/Projects/Microbot_Frieren
git add runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts/CCScriptContractTest.java
git commit -m "test(scripts): add parameterized contract tests for all 5 CC scripts"
```

---

### Task 15: Script Registry Update (Dart) + Final Verification

**Files:**
- Modify: `/mnt/c/Projects/command_center/lib/config/services/app_config_service.dart:37`

- [ ] **Step 1: Update default script registry**

Change line 37 in `app_config_service.dart`:

```dart
// Before:
final scriptRegistry = <String>['Tutorial Journey'].obs;

// After:
final scriptRegistry = <String>[
  'Tutorial Journey',
  'CC Woodcutter',
  'CC Miner',
  'CC Fisher',
  'CC Cooker',
  'CC Combat Trainer',
].obs;
```

- [ ] **Step 2: Run CC tests to verify nothing broke**

Run: `cd /mnt/c/Projects/command_center && flutter test`
Expected: All tests pass

- [ ] **Step 3: Run all Microbot CC script tests**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:test --tests "net.runelite.client.plugins.microbot.commandcenter.scripts.*"`
Expected: All ~57 tests pass (5+4+5+3+4+3+4+4+5+4+6+6 behavior+script+contract tests)

- [ ] **Step 4: Verify compilation of full project**

Run: `cd /mnt/c/Projects/Microbot_Frieren && ./gradlew :runelite-client:compileJava`
Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Commit Dart change**

```bash
cd /mnt/c/Projects/command_center
git add lib/config/services/app_config_service.dart
git commit -m "feat(scripts): add 5 CC script names to default registry"
```

---

## Test Summary

| Task | Component | Test Count |
|------|-----------|-----------|
| 3 | EatingBehavior | 5 |
| 4 | BankingBehavior | 4 |
| 5 | LootingBehavior | 5 |
| 6 | BuryBonesBehavior | 3 |
| 7 | DeathRecoveryBehavior | 4 |
| 8 | StuckDetectionBehavior | 3 |
| 9 | Woodcutter state machine | 4 |
| 10 | Miner state machine | 4 |
| 11 | Fisher state machine | 5 |
| 12 | Cooker state machine | 4 |
| 13 | Combat state machine | 6 |
| 14 | Contract tests (6 × 5) | 30 |
| **Total** | | **~77** |

## File Inventory

**New Java source files:** 29 (framework core: 2, behaviors: 7, scripts: 20)
**New Java test files:** 12
**Modified Dart files:** 1

**Estimated LOC:** ~2,100 source + ~1,200 tests = ~3,300 total
