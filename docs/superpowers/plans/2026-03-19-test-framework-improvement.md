# Bot Scripts Test Framework Improvement Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build reusable test harnesses (CCBehaviorTestBase, CCScriptTestUtils, StubCCScript) and expand contract tests so future scripts get correctness guarantees automatically.

**Architecture:** Three framework pieces — a utility class for reflection-based test access to CCScript internals, a reusable script stub for behaviors that need a script reference, and an abstract test base that auto-runs priority/name/reset contract tests on any CCBehavior. Existing tests are migrated to use these, and a new parameterized contract test verifies that every script's `configure()` registers mandatory behaviors and sets an antiban template.

**Tech Stack:** Java 11, JUnit 4.12, Mockito 3.1.0 (for config interface mocking only)

**Working directory:** `/mnt/c/Projects/Microbot_Frieren/.worktrees/bot-scripts`

---

## Key Paths

```
SRC  = runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/scripts
TEST = runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/scripts
PKG  = net.runelite.client.plugins.microbot.commandcenter.scripts
```

## File Inventory

**New test files (4):**

| File | Responsibility |
|------|---------------|
| `TEST/core/CCScriptTestUtils.java` | Reflection utilities: inject config, call configure(), read behaviors list, check antiban template |
| `TEST/core/StubCCScript.java` | Minimal reusable CCScript with controllable `getMillisSinceLastStateChange()` for behavior tests |
| `TEST/core/CCBehaviorTestBase.java` | Abstract base class providing 3 auto-inherited contract tests for any CCBehavior |
| `TEST/CCScriptConfigureContractTest.java` | Parameterized test verifying `configure()` registers DeathRecovery, StuckDetection (with script ref), and antiban template across all 5 scripts |

**Modified test files (12):**

| File | Change |
|------|--------|
| `TEST/core/behaviors/EatingBehaviorTest.java` | Extend CCBehaviorTestBase, remove redundant priority test |
| `TEST/core/behaviors/BankingBehaviorTest.java` | Extend CCBehaviorTestBase, remove redundant priority + name tests |
| `TEST/core/behaviors/LootingBehaviorTest.java` | Extend CCBehaviorTestBase, remove redundant priority + name tests |
| `TEST/core/behaviors/BuryBonesBehaviorTest.java` | Extend CCBehaviorTestBase (gains missing priority + name + reset tests) |
| `TEST/core/behaviors/DeathRecoveryBehaviorTest.java` | Extend CCBehaviorTestBase, remove redundant priority + name tests |
| `TEST/core/behaviors/StuckDetectionBehaviorTest.java` | Extend CCBehaviorTestBase, rewrite shouldActivate tests using StubCCScript |
| `TEST/woodcutting/CCWoodcuttingScriptTest.java` | Add steady-state + drop-path tests |
| `TEST/mining/CCMiningScriptTest.java` | Add steady-state test |
| `TEST/fishing/CCFishingScriptTest.java` | Add steady-state test |
| `TEST/cooking/CCCookingScriptTest.java` | Add steady-state test |
| `TEST/combat/CCCombatScriptTest.java` | Add steady-state test |
| `TEST/CCScriptContractTest.java` | Add `pluginClass_extendsMicrobotPlugin` test |

**No production code changes required.**

---

## Chunk 1: Test Framework Foundation

### Task 1: CCScriptTestUtils

**Files:**
- Create: `TEST/core/CCScriptTestUtils.java`
- Test: self-verified by Task 6 (CCScriptConfigureContractTest uses all 4 utilities)

Reflection-based utilities that give tests access to CCScript's private internals without modifying production code. Follows the same "test seam" philosophy as the existing package-private `reportStatus()` and `resetAntiban()` overrides, but works across packages.

- [ ] **Step 1: Write CCScriptTestUtils**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core;

import net.runelite.client.config.Config;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Collections;
import java.util.List;
import java.util.function.Consumer;

/**
 * Reflection-based test utilities for CCScript internals.
 * Provides access to private fields without modifying production code.
 */
public final class CCScriptTestUtils {

    private CCScriptTestUtils() {}

    /** Get the registered behaviors list from a script. */
    @SuppressWarnings("unchecked")
    public static List<CCBehavior> getBehaviors(CCScript<?> script) {
        try {
            Field f = CCScript.class.getDeclaredField("behaviors");
            f.setAccessible(true);
            return Collections.unmodifiableList((List<CCBehavior>) f.get(script));
        } catch (Exception e) {
            throw new RuntimeException("Failed to read behaviors field", e);
        }
    }

    /** Check whether setAntiBanTemplate() was called (template is non-null). */
    public static boolean hasAntiBanTemplate(CCScript<?> script) {
        try {
            Field f = CCScript.class.getDeclaredField("antiBanTemplate");
            f.setAccessible(true);
            return f.get(script) != null;
        } catch (Exception e) {
            throw new RuntimeException("Failed to read antiBanTemplate field", e);
        }
    }

    /** Call configure() on a script via reflection (bypasses protected access). */
    public static void callConfigure(CCScript<?> script) {
        try {
            Method m = CCScript.class.getDeclaredMethod("configure");
            m.setAccessible(true);
            m.invoke(script);
        } catch (Exception e) {
            throw new RuntimeException("Failed to call configure()", e);
        }
    }

    /** Inject a config value into a script's @Inject config field via reflection.
     *  Walks the class hierarchy so inherited config fields are found too. */
    public static <C extends Config> void injectConfig(CCScript<?> script, C config) {
        for (Class<?> c = script.getClass(); c != null; c = c.getSuperclass()) {
            for (Field f : c.getDeclaredFields()) {
                if (f.isAnnotationPresent(javax.inject.Inject.class)
                        && Config.class.isAssignableFrom(f.getType())) {
                    try {
                        f.setAccessible(true);
                        f.set(script, config);
                    } catch (Exception e) {
                        throw new RuntimeException("Failed to inject config", e);
                    }
                    return;
                }
            }
        }
        throw new IllegalStateException(
            "No @Inject Config field found on " + script.getClass().getSimpleName());
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TEST/core/CCScriptTestUtils.java
git commit -m "test(scripts): add CCScriptTestUtils reflection utilities"
```

---

### Task 2: StubCCScript

**Files:**
- Create: `TEST/core/StubCCScript.java`

A minimal, test-safe CCScript that provides controllable `getMillisSinceLastStateChange()`. Used by StuckDetectionBehaviorTest (Task 4) and available to any future behavior test that needs a script reference.

The key problem it solves: `StuckDetectionBehavior.shouldActivate()` has a `script != null` guard — without a real script reference, the test is forced to override `shouldActivate()` itself (which means it's not testing production code). `StubCCScript` gives a real script object without starting any executor or touching game APIs.

- [ ] **Step 1: Write StubCCScript**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core;

/**
 * Minimal CCScript for testing behaviors that need a script reference.
 * Overrides reportStatus() and resetAntiban() to no-op (avoids game API calls).
 * Provides controllable getMillisSinceLastStateChange() for StuckDetectionBehavior.
 */
public class StubCCScript extends CCScript<StubCCScript.State> {

    public enum State { ACTIVE }

    // Override the inherited 10-thread pool with a zero-core pool to avoid
    // spawning idle threads in tests (Script base class creates it at init time).
    { scheduledExecutorService = java.util.concurrent.Executors.newScheduledThreadPool(0); }

    private long stubbedMillisSinceLastStateChange = 0;

    @Override protected void configure() {}
    @Override protected State getInitialState() { return State.ACTIVE; }
    @Override protected State onTick(State currentState) { return currentState; }
    @Override void reportStatus(boolean running) {}
    @Override void resetAntiban() {}

    /** Set the value returned by getMillisSinceLastStateChange(). */
    public void setStubbedMillisSinceLastStateChange(long millis) {
        this.stubbedMillisSinceLastStateChange = millis;
    }

    @Override
    public long getMillisSinceLastStateChange() {
        return stubbedMillisSinceLastStateChange;
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TEST/core/StubCCScript.java
git commit -m "test(scripts): add StubCCScript for behavior testing"
```

---

### Task 3: CCBehaviorTestBase

**Files:**
- Create: `TEST/core/CCBehaviorTestBase.java`

Abstract base class that provides 3 automatic contract tests for any CCBehavior. When a behavior test `extends CCBehaviorTestBase<EatingBehavior>`, it inherits:
- `contract_priorityMatchesExpected()` — verifies `priority()` returns the declared value
- `contract_nameMatchesExpected()` — verifies `name()` returns the declared string
- `contract_resetIsSafe()` — verifies `reset()` does not throw

These 3 tests currently exist as explicit tests in some behavior files but are missing in others (BuryBones has no priority or name tests). The base class ensures every behavior gets them automatically.

- [ ] **Step 1: Write CCBehaviorTestBase**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Abstract base for CCBehavior unit tests.
 * Subclasses implement 3 abstract methods and inherit 3 contract tests automatically.
 *
 * Usage:
 * <pre>
 * public class EatingBehaviorTest extends CCBehaviorTestBase&lt;EatingBehavior&gt; {
 *     &#064;Override protected EatingBehavior createDefaultBehavior() {
 *         return new EatingBehavior(50) {
 *             &#064;Override protected int getHpPercent() { return 100; }
 *             &#064;Override protected boolean hasFood() { return false; }
 *             &#064;Override public void execute() {}
 *         };
 *     }
 *     &#064;Override protected int expectedPriority() { return 10; }
 *     &#064;Override protected String expectedName() { return "Eating"; }
 *     // ... additional shouldActivate tests ...
 * }
 * </pre>
 */
public abstract class CCBehaviorTestBase<B extends CCBehavior> {

    /** Create a testable instance with safe (no-op) game query overrides. */
    protected abstract B createDefaultBehavior();

    /** Expected return value of priority(). */
    protected abstract int expectedPriority();

    /** Expected return value of name(). */
    protected abstract String expectedName();

    @Test
    public void contract_priorityMatchesExpected() {
        assertEquals(expectedPriority(), createDefaultBehavior().priority());
    }

    @Test
    public void contract_nameMatchesExpected() {
        assertEquals(expectedName(), createDefaultBehavior().name());
    }

    @Test
    public void contract_resetIsSafe() {
        createDefaultBehavior().reset(); // must not throw
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TEST/core/CCBehaviorTestBase.java
git commit -m "test(scripts): add CCBehaviorTestBase with 3 auto-contract tests"
```

---

## Chunk 2: Migrate Existing Tests & Add Configure Contract

### Task 4: Fix StuckDetectionBehaviorTest

**Files:**
- Modify: `TEST/core/behaviors/StuckDetectionBehaviorTest.java`

The current tests override `shouldActivate()` itself in the anonymous subclass, meaning they test the override rather than the production code. This is the only behavior test with this problem.

**Fix:** Use `StubCCScript` (from Task 2) to provide a real script reference, then call the real production `shouldActivate()`.

- [ ] **Step 1: Rewrite StuckDetectionBehaviorTest**

Replace the entire file contents:

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehaviorTestBase;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.StubCCScript;
import org.junit.Test;
import static org.junit.Assert.*;

public class StuckDetectionBehaviorTest extends CCBehaviorTestBase<StuckDetectionBehavior> {

    @Override
    protected StuckDetectionBehavior createDefaultBehavior() {
        return new StuckDetectionBehavior();
    }

    @Override protected int expectedPriority() { return 1; }
    @Override protected String expectedName() { return "StuckDetection"; }

    @Test
    public void shouldActivate_whenStuckBeyondThreshold() {
        StubCCScript stub = new StubCCScript();
        stub.setStubbedMillisSinceLastStateChange(61_000);

        StuckDetectionBehavior b = new StuckDetectionBehavior();
        b.setScript(stub);

        assertTrue("Should activate when idle > 60s", b.shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenWithinThreshold() {
        StubCCScript stub = new StubCCScript();
        stub.setStubbedMillisSinceLastStateChange(30_000);

        StuckDetectionBehavior b = new StuckDetectionBehavior();
        b.setScript(stub);

        assertFalse("Should not activate within threshold", b.shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenScriptIsNull() {
        StuckDetectionBehavior b = new StuckDetectionBehavior();
        // script is null by default
        assertFalse("Should not activate without script reference", b.shouldActivate());
    }

    @Test
    public void shouldNotActivate_atExactThreshold() {
        StubCCScript stub = new StubCCScript();
        stub.setStubbedMillisSinceLastStateChange(60_000);

        StuckDetectionBehavior b = new StuckDetectionBehavior();
        b.setScript(stub);

        assertFalse("Should not activate at exactly 60s (strict >)", b.shouldActivate());
    }
}
```

- [ ] **Step 2: Verify tests pass conceptually**

Expected: 7 tests total (4 explicit + 3 inherited from CCBehaviorTestBase).
Previous: 3 tests, 2 of which tested overridden `shouldActivate()` (not production code).

- [ ] **Step 3: Commit**

```bash
git add TEST/core/behaviors/StuckDetectionBehaviorTest.java
git commit -m "test(scripts): fix StuckDetection tests to exercise real shouldActivate()"
```

---

### Task 5: Migrate Behavior Tests to CCBehaviorTestBase

**Files:**
- Modify: `TEST/core/behaviors/EatingBehaviorTest.java`
- Modify: `TEST/core/behaviors/BankingBehaviorTest.java`
- Modify: `TEST/core/behaviors/LootingBehaviorTest.java`
- Modify: `TEST/core/behaviors/BuryBonesBehaviorTest.java`
- Modify: `TEST/core/behaviors/DeathRecoveryBehaviorTest.java`

Each file: extend `CCBehaviorTestBase`, add `createDefaultBehavior()`/`expectedPriority()`/`expectedName()`, remove now-redundant explicit tests.

- [ ] **Step 1: Migrate EatingBehaviorTest**

Replace the entire file:

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehaviorTestBase;
import org.junit.Test;
import static org.junit.Assert.*;

public class EatingBehaviorTest extends CCBehaviorTestBase<EatingBehavior> {

    @Override
    protected EatingBehavior createDefaultBehavior() {
        return new EatingBehavior(50) {
            @Override protected int getHpPercent() { return 100; }
            @Override protected boolean hasFood() { return false; }
            @Override public void execute() {}
        };
    }

    @Override protected int expectedPriority() { return 10; }
    @Override protected String expectedName() { return "Eating"; }

    private EatingBehavior behaviorWith(int threshold, int hpPercent, boolean hasFood) {
        return new EatingBehavior(threshold) {
            @Override protected int getHpPercent() { return hpPercent; }
            @Override protected boolean hasFood() { return hasFood; }
            @Override public void execute() {}
        };
    }

    @Test
    public void shouldActivate_whenHpBelowThreshold_andHasFood() {
        assertTrue(behaviorWith(50, 40, true).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenHpAboveThreshold() {
        assertFalse(behaviorWith(50, 60, true).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenNoFood() {
        assertFalse(behaviorWith(50, 30, false).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenHpExactlyAtThreshold() {
        assertFalse(behaviorWith(50, 50, true).shouldActivate());
    }
}
```

Changes: extends `CCBehaviorTestBase`, adds 3 abstract method impls, removes `priority_is10()` (now inherited as `contract_priorityMatchesExpected()`). Test count: 4 explicit + 3 inherited = 7 (was 5).

- [ ] **Step 2: Migrate BankingBehaviorTest**

Replace the entire file:

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.api.coords.WorldPoint;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehaviorTestBase;
import org.junit.Test;
import static org.junit.Assert.*;

public class BankingBehaviorTest extends CCBehaviorTestBase<BankingBehavior> {

    @Override
    protected BankingBehavior createDefaultBehavior() {
        BankingConfig config = new BankingConfig(null, null, null);
        return new BankingBehavior(config, () -> null) {
            @Override protected boolean isInventoryFull() { return false; }
            @Override protected boolean walkToAndOpenBank() { return false; }
            @Override protected boolean isBankOpen() { return false; }
            @Override protected void depositMatchingItems() {}
            @Override protected void withdrawConfiguredItems() {}
            @Override protected void closeBank() {}
            @Override protected void walkToActivityLocation() {}
        };
    }

    @Override protected int expectedPriority() { return 50; }
    @Override protected String expectedName() { return "Banking"; }

    private BankingBehavior behaviorWith(boolean inventoryFull, boolean bankOpen) {
        BankingConfig config = new BankingConfig(
            item -> item.getName().contains("Logs"), null, null
        );
        return new BankingBehavior(config, () -> new WorldPoint(3200, 3200, 0)) {
            @Override protected boolean isInventoryFull() { return inventoryFull; }
            @Override protected boolean walkToAndOpenBank() { return bankOpen; }
            @Override protected boolean isBankOpen() { return bankOpen; }
            @Override protected void depositMatchingItems() {}
            @Override protected void withdrawConfiguredItems() {}
            @Override protected void closeBank() {}
            @Override protected void walkToActivityLocation() {}
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
    public void execute_whenBankOpens_completesFullCycle() {
        boolean[] called = new boolean[4];
        BankingConfig config = new BankingConfig(
            item -> item.getName().contains("Logs"), null, null
        );
        BankingBehavior b = new BankingBehavior(config, () -> new WorldPoint(3200, 3200, 0)) {
            @Override protected boolean isInventoryFull() { return true; }
            @Override protected boolean walkToAndOpenBank() { return true; }
            @Override protected boolean isBankOpen() { return true; }
            @Override protected void depositMatchingItems() { called[0] = true; }
            @Override protected void withdrawConfiguredItems() { called[1] = true; }
            @Override protected void closeBank() { called[2] = true; }
            @Override protected void walkToActivityLocation() { called[3] = true; }
        };
        b.execute();
        assertTrue("deposit called", called[0]);
        assertTrue("withdraw called", called[1]);
        assertTrue("closeBank called", called[2]);
        assertTrue("walkBack called", called[3]);
    }

    @Test
    public void execute_whenBankFailsToOpen_abortsEarly() {
        boolean[] called = new boolean[1];
        BankingConfig config = new BankingConfig(null, null, null);
        BankingBehavior b = new BankingBehavior(config, () -> null) {
            @Override protected boolean isInventoryFull() { return true; }
            @Override protected boolean walkToAndOpenBank() { return false; }
            @Override protected boolean isBankOpen() { return false; }
            @Override protected void depositMatchingItems() { called[0] = true; }
            @Override protected void withdrawConfiguredItems() {}
            @Override protected void closeBank() {}
            @Override protected void walkToActivityLocation() {}
        };
        b.execute();
        assertFalse("deposit should NOT be called", called[0]);
    }
}
```

Changes: removes `priority_is50()` and `name_isBanking()`. Test count: 4 explicit + 3 inherited = 7 (was 6).

- [ ] **Step 3: Migrate LootingBehaviorTest**

Replace the entire file:

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehaviorTestBase;
import org.junit.Test;
import java.util.List;
import static org.junit.Assert.*;

public class LootingBehaviorTest extends CCBehaviorTestBase<LootingBehavior> {

    @Override
    protected LootingBehavior createDefaultBehavior() {
        return new LootingBehavior(List.of(), 10) {
            @Override protected boolean hasMatchingGroundItem() { return false; }
            @Override public void execute() {}
        };
    }

    @Override protected int expectedPriority() { return 40; }
    @Override protected String expectedName() { return "Looting"; }

    private LootingBehavior behaviorWith(List<String> itemNames, int radius, boolean matchingItemOnGround) {
        return new LootingBehavior(itemNames, radius) {
            @Override protected boolean hasMatchingGroundItem() { return matchingItemOnGround; }
            @Override public void execute() {}
        };
    }

    @Test
    public void shouldActivate_whenItemsConfigured_andMatchingItemOnGround() {
        assertTrue(behaviorWith(List.of("Bones"), 10, true).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenNoItemsConfigured() {
        assertFalse(behaviorWith(List.of(), 10, true).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenNoMatchingItemOnGround() {
        assertFalse(behaviorWith(List.of("Bones"), 10, false).shouldActivate());
    }
}
```

Changes: removes `priority_is40()` and `name_isLooting()`. Test count: 3 explicit + 3 inherited = 6 (was 5).

- [ ] **Step 4: Migrate BuryBonesBehaviorTest**

Replace the entire file:

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehaviorTestBase;
import org.junit.Test;
import static org.junit.Assert.*;

public class BuryBonesBehaviorTest extends CCBehaviorTestBase<BuryBonesBehavior> {

    @Override
    protected BuryBonesBehavior createDefaultBehavior() {
        return new BuryBonesBehavior() {
            @Override protected boolean hasBones() { return false; }
            @Override protected boolean isInCombat() { return false; }
            @Override public void execute() {}
        };
    }

    @Override protected int expectedPriority() { return 45; }
    @Override protected String expectedName() { return "BuryBones"; }

    private BuryBonesBehavior behaviorWith(boolean hasBones, boolean inCombat) {
        return new BuryBonesBehavior() {
            @Override protected boolean hasBones() { return hasBones; }
            @Override protected boolean isInCombat() { return inCombat; }
            @Override public void execute() {}
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

Changes: gains priority, name, and reset tests it was previously missing. Test count: 3 explicit + 3 inherited = 6 (was 3).

- [ ] **Step 5: Migrate DeathRecoveryBehaviorTest**

Replace the entire file:

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors;

import net.runelite.api.coords.WorldPoint;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehaviorTestBase;
import org.junit.Test;
import static org.junit.Assert.*;

public class DeathRecoveryBehaviorTest extends CCBehaviorTestBase<DeathRecoveryBehavior> {

    @Override
    protected DeathRecoveryBehavior createDefaultBehavior() {
        return new DeathRecoveryBehavior(() -> null) {
            @Override protected boolean isPlayerDead() { return false; }
            @Override public void execute() {}
        };
    }

    @Override protected int expectedPriority() { return 5; }
    @Override protected String expectedName() { return "DeathRecovery"; }

    private DeathRecoveryBehavior behaviorWith(boolean isDead) {
        return new DeathRecoveryBehavior(() -> new WorldPoint(3200, 3200, 0)) {
            @Override protected boolean isPlayerDead() { return isDead; }
            @Override public void execute() {}
        };
    }

    @Test
    public void shouldActivate_whenPlayerDead() {
        assertTrue(behaviorWith(true).shouldActivate());
    }

    @Test
    public void shouldNotActivate_whenAlive() {
        assertFalse(behaviorWith(false).shouldActivate());
    }
}
```

Changes: removes `priority_is5()` and `name_isDeathRecovery()`. Test count: 2 explicit + 3 inherited = 5 (was 4).

- [ ] **Step 6: Commit all behavior test migrations**

```bash
git add TEST/core/behaviors/
git commit -m "test(scripts): migrate all behavior tests to CCBehaviorTestBase"
```

---

### Task 6: CCScriptConfigureContractTest

**Files:**
- Create: `TEST/CCScriptConfigureContractTest.java`
- Modify: `TEST/CCScriptContractTest.java` (add MicrobotPlugin base class check)

Parameterized test that instantiates each script, calls `configure()` via reflection, and verifies the 4 configure contracts that every script must satisfy:
1. Registers a `DeathRecoveryBehavior`
2. Registers a `StuckDetectionBehavior`
3. StuckDetection has its `script` reference set (non-null)
4. Sets an antiban template via `setAntiBanTemplate()`

With null config, only unconditional behaviors register — this is exactly what we want to test.

- [ ] **Step 1: Write CCScriptConfigureContractTest**

```java
package net.runelite.client.plugins.microbot.commandcenter.scripts;

import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCBehavior;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCScript;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCScriptTestUtils;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.DeathRecoveryBehavior;
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.behaviors.StuckDetectionBehavior;
import net.runelite.client.plugins.microbot.commandcenter.scripts.woodcutting.CCWoodcuttingScript;
import net.runelite.client.plugins.microbot.commandcenter.scripts.mining.CCMiningScript;
import net.runelite.client.plugins.microbot.commandcenter.scripts.fishing.CCFishingScript;
import net.runelite.client.plugins.microbot.commandcenter.scripts.cooking.CCCookingScript;
import net.runelite.client.plugins.microbot.commandcenter.scripts.combat.CCCombatScript;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;

import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;

import static org.junit.Assert.*;

/**
 * Verifies that every CC script's configure() method satisfies framework contracts.
 * Adding a new script means adding one line to the parameters list.
 */
@RunWith(Parameterized.class)
public class CCScriptConfigureContractTest {

    @Parameterized.Parameters(name = "{0}")
    public static Collection<Object[]> scripts() {
        return Arrays.asList(new Object[][]{
            {"CCWoodcuttingScript", CCWoodcuttingScript.class},
            {"CCMiningScript", CCMiningScript.class},
            {"CCFishingScript", CCFishingScript.class},
            {"CCCookingScript", CCCookingScript.class},
            {"CCCombatScript", CCCombatScript.class},
        });
    }

    private final String scriptName;
    private final Class<? extends CCScript<?>> scriptClass;

    @SuppressWarnings("unchecked")
    public CCScriptConfigureContractTest(String scriptName, Class<?> scriptClass) {
        this.scriptName = scriptName;
        this.scriptClass = (Class<? extends CCScript<?>>) scriptClass;
    }

    private CCScript<?> createAndConfigure() {
        try {
            CCScript<?> script = scriptClass.getDeclaredConstructor().newInstance();
            CCScriptTestUtils.callConfigure(script);
            return script;
        } catch (Exception e) {
            throw new RuntimeException("Cannot instantiate " + scriptName, e);
        }
    }

    @Test
    public void configure_registersDeathRecoveryBehavior() {
        List<CCBehavior> behaviors = CCScriptTestUtils.getBehaviors(createAndConfigure());
        assertTrue(scriptName + " must register DeathRecoveryBehavior",
            behaviors.stream().anyMatch(b -> b instanceof DeathRecoveryBehavior));
    }

    @Test
    public void configure_registersStuckDetectionBehavior() {
        List<CCBehavior> behaviors = CCScriptTestUtils.getBehaviors(createAndConfigure());
        assertTrue(scriptName + " must register StuckDetectionBehavior",
            behaviors.stream().anyMatch(b -> b instanceof StuckDetectionBehavior));
    }

    @Test
    public void configure_stuckDetectionHasScriptReference() {
        CCScript<?> script = createAndConfigure();
        StuckDetectionBehavior stuck = CCScriptTestUtils.getBehaviors(script).stream()
            .filter(b -> b instanceof StuckDetectionBehavior)
            .map(b -> (StuckDetectionBehavior) b)
            .findFirst().orElse(null);
        assertNotNull("StuckDetection must be registered", stuck);

        // Verify setScript(this) was called by reading the private field
        try {
            Field f = StuckDetectionBehavior.class.getDeclaredField("script");
            f.setAccessible(true);
            assertNotNull(scriptName + " must call stuck.setScript(this)", f.get(stuck));
        } catch (Exception e) {
            throw new RuntimeException("Cannot read StuckDetection.script field", e);
        }
    }

    @Test
    public void configure_setsAntiBanTemplate() {
        assertTrue(scriptName + " must call setAntiBanTemplate()",
            CCScriptTestUtils.hasAntiBanTemplate(createAndConfigure()));
    }
}
```

- [ ] **Step 2: Add MicrobotPlugin base class check to existing CCScriptContractTest**

Add this test to `TEST/CCScriptContractTest.java` after the existing tests:

```java
@Test
public void pluginClass_extendsMicrobotPlugin() {
    assertTrue(pluginClass.getSimpleName() + " should extend MicrobotPlugin",
        net.runelite.client.plugins.microbot.MicrobotPlugin.class.isAssignableFrom(pluginClass));
}
```

This catches the same bug the Phase 3 reviewer found — if a future script extends `Plugin` instead of `MicrobotPlugin`, this test fails.

- [ ] **Step 3: Commit**

```bash
git add TEST/CCScriptConfigureContractTest.java TEST/CCScriptContractTest.java
git commit -m "test(scripts): add configure() contract tests + MicrobotPlugin base check"
```

---

## Chunk 3: Close Test Gaps

### Task 7: Add Missing State Machine Tests

**Files:**
- Modify: `TEST/woodcutting/CCWoodcuttingScriptTest.java`
- Modify: `TEST/mining/CCMiningScriptTest.java`
- Modify: `TEST/fishing/CCFishingScriptTest.java`
- Modify: `TEST/cooking/CCCookingScriptTest.java`
- Modify: `TEST/combat/CCCombatScriptTest.java`

Adds two categories of missing tests:
1. **Steady-state** (IDLE + no resource/target → stays IDLE) — missing in all 5 scripts
2. **Drop-path** (inventory full + config says drop → calls drop, stays active) — woodcutting as template using Mockito for config

- [ ] **Step 1: Add steady-state test to CCWoodcuttingScriptTest + drop-path test**

Add these tests to the existing file:

```java
// Add import at the top:
import static org.mockito.Mockito.*;

// Add after existing tests:

@Test
public void idle_whenNoTree_staysIdle() {
    CCWoodcuttingScript s = scriptWith(false, false);
    assertEquals(CCWoodcuttingScript.State.IDLE,
        s.onTick(CCWoodcuttingScript.State.IDLE));
}

@Test
public void chopping_whenInventoryFull_andConfigDrop_dropsLogs() {
    boolean[] dropCalled = new boolean[1];
    CCWoodcuttingConfig config = mock(CCWoodcuttingConfig.class, CALLS_REAL_METHODS);
    when(config.bankLogs()).thenReturn(false);

    CCWoodcuttingScript s = new CCWoodcuttingScript() {
        @Override protected boolean isPlayerBusy() { return false; }
        @Override protected boolean findAndChopTree() { return false; }
        @Override protected boolean isInventoryFull() { return true; }
        @Override protected void dropAllLogs() { dropCalled[0] = true; }
    };
    CCScriptTestUtils.injectConfig(s, config);

    assertEquals(CCWoodcuttingScript.State.CHOPPING,
        s.onTick(CCWoodcuttingScript.State.CHOPPING));
    assertTrue("dropAllLogs should be called", dropCalled[0]);
}
```

Also add the import for CCScriptTestUtils:
```java
import net.runelite.client.plugins.microbot.commandcenter.scripts.core.CCScriptTestUtils;
```

- [ ] **Step 2: Add steady-state tests to remaining 4 script tests**

Add to `CCMiningScriptTest.java`:
```java
@Test
public void idle_whenNoRock_staysIdle() {
    assertEquals(CCMiningScript.State.IDLE,
        scriptWith(false, false).onTick(CCMiningScript.State.IDLE));
}
```

Add to `CCFishingScriptTest.java`:
```java
@Test
public void idle_whenNoSpot_staysIdle() {
    assertEquals(CCFishingScript.State.IDLE,
        scriptWith(false, false, true).onTick(CCFishingScript.State.IDLE));
}
```

Add to `CCCookingScriptTest.java`:
```java
@Test
public void idle_whenNoRawFood_staysIdle() {
    assertEquals(CCCookingScript.State.IDLE,
        scriptWith(false, false, false).onTick(CCCookingScript.State.IDLE));
}
```

Add to `CCCombatScriptTest.java` (already has this test — `idle_whenNoMonster_stays` exists. Skip this file for steady-state.)

- [ ] **Step 3: Commit**

```bash
git add TEST/woodcutting/CCWoodcuttingScriptTest.java \
        TEST/mining/CCMiningScriptTest.java \
        TEST/fishing/CCFishingScriptTest.java \
        TEST/cooking/CCCookingScriptTest.java
git commit -m "test(scripts): add steady-state + drop-path gap tests"
```

---

## Test Count Summary

| Component | Before | After | Delta |
|-----------|--------|-------|-------|
| CCScript lifecycle | 4 | 4 | — |
| EatingBehavior | 5 | 7 | +2 |
| BankingBehavior | 6 | 7 | +1 |
| LootingBehavior | 5 | 6 | +1 |
| BuryBonesBehavior | 3 | 6 | +3 |
| DeathRecoveryBehavior | 4 | 5 | +1 |
| StuckDetectionBehavior | 3 | 7 | +4 |
| Woodcutting script | 4 | 6 | +2 |
| Mining script | 4 | 5 | +1 |
| Fishing script | 5 | 6 | +1 |
| Cooking script | 4 | 5 | +1 |
| Combat script | 6 | 6 | — |
| Plugin descriptor contract | 30 | 35 | +5 |
| **Configure contract (new)** | 0 | **20** | **+20** |
| **Total** | **83** | **~120** | **+37** |

---

## How to Test a New CC Script (Framework Guide)

When adding a new script (e.g., `CC Prayer`), the framework gives you automatic coverage if you follow this pattern:

### 1. Behavior tests (if adding new behaviors)

```java
public class PrayerBehaviorTest extends CCBehaviorTestBase<PrayerBehavior> {
    @Override protected PrayerBehavior createDefaultBehavior() {
        return new PrayerBehavior() {
            @Override protected boolean hasPrayerPoints() { return false; }
            @Override public void execute() {}
        };
    }
    @Override protected int expectedPriority() { return 15; }
    @Override protected String expectedName() { return "Prayer"; }

    // You get priority, name, and reset tests for FREE.
    // Only write shouldActivate tests specific to this behavior.
}
```

### 2. Script state machine tests

```java
public class CCPrayerScriptTest {
    private CCPrayerScript scriptWith(boolean busy, boolean altarFound) {
        return new CCPrayerScript() {
            @Override protected boolean isPlayerBusy() { return busy; }
            @Override protected boolean findAndPray() { return altarFound; }
        };
    }

    // Test every state × condition combination:
    // - Active + busy → stays active
    // - Active + resource found → stays active
    // - Active + nothing → goes idle
    // - IDLE + resource found → goes active
    // - IDLE + nothing → stays idle  ← DON'T FORGET THIS ONE
}
```

### 3. Register in contract tests

Add one line to each parameterized test:

**`CCScriptContractTest` (plugin annotations):**
```java
{"CC Prayer", CCPrayerPlugin.class},
```

**`CCScriptConfigureContractTest` (configure behavior):**
```java
{"CCPrayerScript", CCPrayerScript.class},
```

This automatically gives you 4 configure contract tests (DeathRecovery, StuckDetection with script ref, antiban template) and 7 plugin descriptor tests (annotation exists, name prefix, name match, enabledByDefault, both tags, extends MicrobotPlugin).

### 4. Config-present tests (for conditional branches)

Use `CCScriptTestUtils.injectConfig()` + Mockito:
```java
CCPrayerConfig config = mock(CCPrayerConfig.class, CALLS_REAL_METHODS);
when(config.useBones()).thenReturn(true);
CCScriptTestUtils.injectConfig(script, config);
```
