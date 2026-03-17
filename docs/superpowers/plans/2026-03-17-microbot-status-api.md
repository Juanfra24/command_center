# Status API, Auto-Login & Command Center Integration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a localhost HTTP Status API to the Microbot fork, auto-login and script auto-start from profiles, and integrate all of it into Command Center's WatchdogService for rich bot state monitoring.

**Architecture:** Java-side: JDK HttpServer on `127.0.0.1` with ephemeral port + file-based discovery. AutoLoginPlugin reads credentials from profile dir. ScriptAutoStartPlugin enables plugins by name after login. Dart-side: MicrobotEngine passes `--cc-profile-dir` and `--status-port-file`, polls for port file, WatchdogService fetches `/status` on each tick.

**Tech Stack:** Java 17 (JDK HttpServer, Gson), Dart/Flutter (Command Center), `flutter_test`

**Spec:** `docs/superpowers/specs/2026-03-17-microbot-fork-and-scripts-design.md` (Parts 3, 4, and remaining Part 5 Dart-side changes deferred from Plan 1)

**Depends on:** Plan 1 (Fork Setup) must be complete — the `commandcenter/` package directory and fork repo must exist. Plan 1 already covers `MicrobotJarDownloader` URL change, `AppConfigService.getGithubPat()`, and GitHub Actions CI/CD.

---

## Chunk 1: Java-Side Status API

### Task 1: StatusApiServer — Ephemeral HTTP Server

**Files:**
- Create: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/status/StatusApiServer.java`

**Context:** Uses `com.sun.net.httpserver.HttpServer` (built into JDK, no dependencies). Binds to `127.0.0.1:0` (OS picks free port), writes actual port to a file. Starts in `MicrobotPlugin.startUp()`, stops in `MicrobotPlugin.shutDown()`.

- [ ] **Step 1: Create status package directory**

```bash
mkdir -p runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/status/
```

- [ ] **Step 2: Create StatusApiServer.java**

```java
package net.runelite.client.plugins.microbot.commandcenter.status;

import com.sun.net.httpserver.HttpServer;
import lombok.extern.slf4j.Slf4j;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Lightweight HTTP server bound to localhost only.
 * Exposes /status and /health endpoints for Command Center polling.
 */
@Slf4j
public class StatusApiServer {
    private HttpServer server;
    private int port;
    private final Path portFilePath;
    private final StatusApiHandler handler;

    public StatusApiServer(Path portFilePath, StatusApiHandler handler) {
        this.portFilePath = portFilePath;
        this.handler = handler;
    }

    public void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        port = server.getAddress().getPort();

        server.createContext("/status", handler::handleStatus);
        server.createContext("/health", handler::handleHealth);
        server.setExecutor(null); // default single-thread executor
        server.start();

        // Write port to file for Command Center discovery
        Files.writeString(portFilePath, String.valueOf(port));
        log.info("Status API started on 127.0.0.1:{}", port);
    }

    public void stop() {
        if (server != null) {
            server.stop(0);
            log.info("Status API stopped");
        }
        // Clean up port file
        try {
            Files.deleteIfExists(portFilePath);
        } catch (IOException e) {
            log.warn("Failed to delete port file: {}", e.getMessage());
        }
    }

    public int getPort() {
        return port;
    }
}
```

- [ ] **Step 3: Verify build**

```bash
./gradlew :runelite-client:compileJava
```

Expected: BUILD SUCCESSFUL (StatusApiHandler doesn't exist yet — this step may fail. If so, proceed to Task 2 and compile after both files exist).

- [ ] **Step 4: Commit**

```bash
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/status/StatusApiServer.java
git commit -m "feat(status-api): add ephemeral HTTP server on localhost

StatusApiServer binds to 127.0.0.1:0 (OS picks free port).
Writes actual port to status.port file for Command Center discovery.
Exposes /status and /health endpoints."
```

---

### Task 2: StatusApiHandler — Request Routing

**Files:**
- Create: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/status/StatusApiHandler.java`

**Context:** Routes `/status` and `/health` requests. `/status` returns the full bot status JSON. `/health` returns `{"alive": true}`.

- [ ] **Step 1: Create StatusApiHandler.java**

```java
package net.runelite.client.plugins.microbot.commandcenter.status;

import com.sun.net.httpserver.HttpExchange;
import lombok.extern.slf4j.Slf4j;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

@Slf4j
public class StatusApiHandler {
    private final BotStatusModel statusModel;

    public StatusApiHandler(BotStatusModel statusModel) {
        this.statusModel = statusModel;
    }

    public void handleStatus(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod())) {
            sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
            return;
        }
        try {
            String json = statusModel.toJson();
            sendResponse(exchange, 200, json);
        } catch (Exception e) {
            log.error("Error building status response", e);
            sendResponse(exchange, 500, "{\"error\":\"Internal error\"}");
        }
    }

    public void handleHealth(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod())) {
            sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
            return;
        }
        sendResponse(exchange, 200, "{\"alive\":true}");
    }

    private void sendResponse(HttpExchange exchange, int statusCode, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/status/StatusApiHandler.java
git commit -m "feat(status-api): add request handler for /status and /health"
```

---

### Task 3: BotStatusModel — JSON Response Builder

**Files:**
- Create: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/status/BotStatusModel.java`

**Context:** Collects data from `Microbot.getClient()` (player state, world, XP) and active script (name, runtime). Serialized to JSON via Gson (bundled with RuneLite). Matches the JSON schema in the spec.

- [ ] **Step 1: Create BotStatusModel.java**

```java
package net.runelite.client.plugins.microbot.commandcenter.status;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import lombok.extern.slf4j.Slf4j;
import net.runelite.api.Client;
import net.runelite.api.GameState;
import net.runelite.api.Skill;
import net.runelite.client.plugins.microbot.Microbot;

import java.util.HashMap;
import java.util.Map;

/**
 * Builds the JSON status response by reading game state from the RuneLite Client API.
 * Thread-safe: reads are done on the calling thread (HttpServer executor).
 * All fields are additive-only — new fields may appear, existing fields are never removed.
 */
@Slf4j
public class BotStatusModel {
    private static final Gson GSON = new GsonBuilder().create();
    private static final int SCHEMA_VERSION = 1;

    private final long startTimeMs = System.currentTimeMillis();

    // Injected by MicrobotPlugin when a script starts/stops
    private volatile String activeScriptName;
    private volatile boolean scriptRunning;
    private volatile long scriptStartTimeMs;

    // Injected at construction
    private final int characterId;
    private final String characterName;

    public BotStatusModel(int characterId, String characterName) {
        this.characterId = characterId;
        this.characterName = characterName;
    }

    public void setActiveScript(String name, boolean running) {
        this.activeScriptName = name;
        this.scriptRunning = running;
        if (running) {
            this.scriptStartTimeMs = System.currentTimeMillis();
        }
    }

    public String toJson() {
        Map<String, Object> root = new HashMap<>();
        root.put("version", SCHEMA_VERSION);
        root.put("characterId", characterId);
        root.put("characterName", characterName);

        Client client = Microbot.getClient();
        boolean loggedIn = client != null &&
            client.getGameState() == GameState.LOGGED_IN;

        root.put("loggedIn", loggedIn);
        root.put("status", loggedIn ? (scriptRunning ? "running" : "idle") : "login_screen");

        // Script info
        Map<String, Object> script = new HashMap<>();
        script.put("name", activeScriptName);
        script.put("running", scriptRunning);
        script.put("runtime", scriptRunning
            ? (int) ((System.currentTimeMillis() - scriptStartTimeMs) / 1000)
            : 0);
        root.put("script", script);

        // Player info (safe even when not logged in — returns defaults)
        Map<String, Object> player = new HashMap<>();
        if (loggedIn && client != null) {
            player.put("world", client.getWorld());
            // Location
            var localPlayer = client.getLocalPlayer();
            if (localPlayer != null) {
                var pos = localPlayer.getWorldLocation();
                Map<String, Integer> location = new HashMap<>();
                location.put("x", pos.getX());
                location.put("y", pos.getY());
                player.put("location", location);
            }
            player.put("hitpoints", client.getBoostedSkillLevel(Skill.HITPOINTS));
            player.put("prayer", client.getBoostedSkillLevel(Skill.PRAYER));
            player.put("runEnergy", client.getEnergy() / 100); // RuneLite returns 0-10000
        }
        root.put("player", player);

        // XP info
        Map<String, Object> xp = new HashMap<>();
        // XP tracking requires baseline storage — simplified for now
        xp.put("totalGained", 0);
        xp.put("perHour", 0);
        xp.put("skills", new HashMap<>());
        root.put("xp", xp);

        root.put("uptime", (int) ((System.currentTimeMillis() - startTimeMs) / 1000));

        return GSON.toJson(root);
    }
}
```

- [ ] **Step 2: Verify build**

```bash
./gradlew :runelite-client:compileJava
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**

```bash
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/status/BotStatusModel.java
git commit -m "feat(status-api): add BotStatusModel JSON response builder

Reads game state from Microbot.getClient(): world, location, hitpoints,
prayer, run energy. Tracks script name/runtime via setActiveScript().
Schema version 1, additive-only fields."
```

---

### Task 4: Wire Status API into MicrobotPlugin

**Files:**
- Modify: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/MicrobotPlugin.java`

**Context:** MicrobotPlugin is the main entry point. We start the Status API server in `startUp()` and stop it in `shutDown()`. The `--status-port-file` system property tells us where to write the port file. The `--cc-profile-dir` property provides the profile directory path.

- [ ] **Step 1: Read MicrobotPlugin.java to find startUp/shutDown**

```bash
grep -n "startUp\|shutDown\|onStart\|onStop" \
  runelite-client/src/main/java/net/runelite/client/plugins/microbot/MicrobotPlugin.java
```

- [ ] **Step 2: Add Status API fields and initialization**

Add to MicrobotPlugin's class fields:

```java
import net.runelite.client.plugins.microbot.commandcenter.status.StatusApiServer;
import net.runelite.client.plugins.microbot.commandcenter.status.StatusApiHandler;
import net.runelite.client.plugins.microbot.commandcenter.status.BotStatusModel;
import java.nio.file.Path;
import java.nio.file.Paths;

// Class fields:
private StatusApiServer statusApiServer;
private BotStatusModel botStatusModel;
```

In `startUp()` (or equivalent lifecycle method), add after existing initialization:

```java
// Start Status API if port file path is configured
String portFilePath = System.getProperty("status-port-file");
if (portFilePath != null && !portFilePath.isEmpty()) {
    try {
        // Read characterId and characterName from cc-profile-dir properties
        String profileDir = System.getProperty("cc-profile-dir");
        int charId = 0; // Parsed from profile dir name (bot-<id>)
        String charName = "";
        if (profileDir != null) {
            String dirName = Paths.get(profileDir).getFileName().toString();
            if (dirName.startsWith("bot-")) {
                charId = Integer.parseInt(dirName.substring(4));
            }
        }
        botStatusModel = new BotStatusModel(charId, charName);
        StatusApiHandler handler = new StatusApiHandler(botStatusModel);
        statusApiServer = new StatusApiServer(Path.of(portFilePath), handler);
        statusApiServer.start();
    } catch (Exception e) {
        log.error("Failed to start Status API: {}", e.getMessage());
    }
}
```

In `shutDown()`:

```java
if (statusApiServer != null) {
    statusApiServer.stop();
}
```

- [ ] **Step 3: Verify build**

```bash
./gradlew :runelite-client:compileJava
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(status-api): wire StatusApiServer into MicrobotPlugin lifecycle

Starts Status API in startUp() when --status-port-file is set.
Stops and cleans up port file in shutDown().
Reads characterId from profile directory name."
```

---

## Chunk 2: Auto-Login & Script Auto-Start (Java)

### Task 5: CLI Flag Parsing for --cc-profile-dir and --status-port-file

**Files:**
- Modify: RuneLite's argument parsing (exact file varies — likely `RuneLite.java` or a CLI config class)

**Context:** RuneLite uses JCommander or a custom args parser. We add two custom flags: `--cc-profile-dir` (absolute path to profile directory) and `--status-port-file` (path to write port file). These are set as system properties so any plugin can read them.

- [ ] **Step 1: Find CLI argument parsing**

```bash
grep -rn "JCommander\|args\|parameter\|profile" \
  --include="*.java" \
  runelite-client/src/main/java/net/runelite/client/ \
  | grep -v "plugins/" | head -30
```

- [ ] **Step 2: Add custom CLI flags**

Add to the argument class (or parse manually in main):

```java
// If using JCommander annotations:
@Parameter(names = "--cc-profile-dir", description = "Command Center profile directory")
private String ccProfileDir;

@Parameter(names = "--status-port-file", description = "Path to write Status API port")
private String statusPortFile;
```

Then in `main()` or early startup, set as system properties:

```java
if (ccProfileDir != null) {
    System.setProperty("cc-profile-dir", ccProfileDir);
}
if (statusPortFile != null) {
    System.setProperty("status-port-file", statusPortFile);
}
```

- [ ] **Step 3: Remove old --profile usage for our bot profiles**

Verify whether `--profile` is a RuneLite built-in flag. If so, our `--cc-profile-dir` is intentionally separate and no modification to `--profile` handling is needed. If RuneLite doesn't have `--profile` natively, remove the `--profile=bot-<id>` handling that was added in Spec #1 (it's replaced by `--cc-profile-dir`).

- [ ] **Step 4: Verify build**

```bash
./gradlew :runelite-client:compileJava
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add --cc-profile-dir and --status-port-file CLI flags

Custom flags set as system properties for plugin access.
Separate from RuneLite's --profile to avoid conflicts."
```

---

### Task 6: AutoLoginPlugin — Profile-Based Credential Injection

**Files:**
- Create: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/AutoLoginPlugin.java`

**Context:** Reads `credentials.properties` from `--cc-profile-dir`. On the login screen, injects email + password into the login fields and clicks Login. Handles world selector from `commandcenter.properties`.

- [ ] **Step 1: Create AutoLoginPlugin.java**

```java
package net.runelite.client.plugins.microbot.commandcenter;

import lombok.extern.slf4j.Slf4j;
import net.runelite.api.Client;
import net.runelite.api.GameState;
import net.runelite.api.events.GameStateChanged;
import net.runelite.client.eventbus.Subscribe;
import net.runelite.client.plugins.Plugin;
import net.runelite.client.plugins.PluginDescriptor;

import javax.inject.Inject;
import java.io.FileInputStream;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;

@PluginDescriptor(
    name = "CC Auto Login",
    description = "Auto-login from Command Center profile credentials",
    enabledByDefault = false
)
@Slf4j
public class AutoLoginPlugin extends Plugin {
    @Inject
    private Client client;

    private String email;
    private String password;
    private String world;
    private boolean loginAttempted;

    @Override
    protected void startUp() {
        loginAttempted = false;
        String profileDir = System.getProperty("cc-profile-dir");
        if (profileDir == null || profileDir.isEmpty()) {
            log.warn("No --cc-profile-dir set, AutoLogin disabled");
            return;
        }

        Path profilePath = Paths.get(profileDir);

        // Read credentials
        try {
            Properties creds = new Properties();
            creds.load(new FileInputStream(profilePath.resolve("credentials.properties").toFile()));
            email = creds.getProperty("email");
            password = creds.getProperty("password");
        } catch (Exception e) {
            log.error("Failed to read credentials.properties: {}", e.getMessage());
        }

        // Read world from commandcenter.properties
        try {
            Properties config = new Properties();
            config.load(new FileInputStream(profilePath.resolve("commandcenter.properties").toFile()));
            world = config.getProperty("world");
        } catch (Exception e) {
            log.debug("No commandcenter.properties or no world set");
        }
    }

    @Subscribe
    public void onGameStateChanged(GameStateChanged event) {
        if (event.getGameState() != GameState.LOGIN_SCREEN) return;
        if (loginAttempted) return;
        if (email == null || password == null) return;

        loginAttempted = true;

        // Set world if configured
        if (world != null && !world.isEmpty() && !"auto".equals(world)) {
            try {
                int worldNum = Integer.parseInt(world);
                client.changeWorld(client.createWorld().withId(worldNum));
            } catch (NumberFormatException e) {
                log.warn("Invalid world number: {}", world);
            }
        }

        // Inject credentials
        client.setUsername(email);
        client.setPassword(password);

        // Simulate login button press
        // RuneLite fires LOGIN_SCREEN when ready — we can set credentials directly
        // The actual login is triggered by the client's login field being populated
        log.info("AutoLogin: credentials injected for {}", email.substring(0, 3) + "***");
    }

    @Override
    protected void shutDown() {
        email = null;
        password = null;
        world = null;
    }
}
```

- [ ] **Step 2: Verify build**

```bash
./gradlew :runelite-client:compileJava
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add AutoLoginPlugin for profile-based credential injection

Reads credentials.properties from --cc-profile-dir.
Injects email/password on LOGIN_SCREEN GameState.
Handles world selection from commandcenter.properties.
Credentials never logged (only first 3 chars of email for confirmation)."
```

---

### Task 7: ScriptAutoStartPlugin — Plugin Activation After Login

**Files:**
- Create: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/ScriptAutoStartPlugin.java`

**Context:** After login completes, reads `script` key from `commandcenter.properties` and enables the matching plugin via RuneLite's PluginManager.

- [ ] **Step 1: Create ScriptAutoStartPlugin.java**

```java
package net.runelite.client.plugins.microbot.commandcenter;

import lombok.extern.slf4j.Slf4j;
import net.runelite.api.GameState;
import net.runelite.api.events.GameStateChanged;
import net.runelite.client.eventbus.Subscribe;
import net.runelite.client.plugins.Plugin;
import net.runelite.client.plugins.PluginDescriptor;
import net.runelite.client.plugins.PluginManager;

import javax.inject.Inject;
import java.io.FileInputStream;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;

@PluginDescriptor(
    name = "CC Script Auto-Start",
    description = "Auto-start a script plugin after login from Command Center profile",
    enabledByDefault = false
)
@Slf4j
public class ScriptAutoStartPlugin extends Plugin {
    @Inject
    private PluginManager pluginManager;

    private String targetScriptName;
    private boolean startAttempted;

    @Override
    protected void startUp() {
        startAttempted = false;
        String profileDir = System.getProperty("cc-profile-dir");
        if (profileDir == null || profileDir.isEmpty()) {
            log.warn("No --cc-profile-dir set, ScriptAutoStart disabled");
            return;
        }

        try {
            Properties config = new Properties();
            config.load(new FileInputStream(
                Paths.get(profileDir).resolve("commandcenter.properties").toFile()));
            targetScriptName = config.getProperty("script");
        } catch (Exception e) {
            log.warn("Failed to read commandcenter.properties: {}", e.getMessage());
        }

        if (targetScriptName == null || targetScriptName.isEmpty()) {
            log.info("No script configured for auto-start");
        }
    }

    @Subscribe
    public void onGameStateChanged(GameStateChanged event) {
        if (event.getGameState() != GameState.LOGGED_IN) return;
        if (startAttempted) return;
        if (targetScriptName == null || targetScriptName.isEmpty()) return;

        startAttempted = true;

        // Find matching plugin by @PluginDescriptor name
        for (Plugin plugin : pluginManager.getPlugins()) {
            PluginDescriptor descriptor = plugin.getClass().getAnnotation(PluginDescriptor.class);
            if (descriptor != null && descriptor.name().equals(targetScriptName)) {
                try {
                    pluginManager.setPluginEnabled(plugin, true);
                    pluginManager.startPlugin(plugin);
                    log.info("ScriptAutoStart: enabled '{}'", targetScriptName);
                    return;
                } catch (Exception e) {
                    log.error("Failed to start plugin '{}': {}", targetScriptName, e.getMessage());
                    return;
                }
            }
        }

        log.warn("ScriptAutoStart: plugin '{}' not found", targetScriptName);
    }

    @Override
    protected void shutDown() {
        targetScriptName = null;
    }
}
```

- [ ] **Step 2: Verify build**

```bash
./gradlew :runelite-client:compileJava
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ScriptAutoStartPlugin for profile-based script activation

Reads script name from commandcenter.properties after login.
Finds matching @PluginDescriptor by name, enables and starts it.
Falls back gracefully if no script configured or plugin not found."
```

---

## Chunk 3: Dart-Side Integration

### Task 8: BotStatus Dart Model

**Files:**
- Create: `lib/config/services/bot_engine/bot_status.dart`
- Test: `test/config/services/bot_engine/bot_status_test.dart`

**Context:** Parses the JSON response from the Status API's `/status` endpoint. Must tolerate unknown fields (additive-only schema).

- [ ] **Step 1: Write the failing test**

Create `test/config/services/bot_engine/bot_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/bot_status.dart';

void main() {
  group('BotStatus', () {
    test('fromJson parses full status response', () {
      final json = {
        'version': 1,
        'characterId': 42,
        'characterName': 'BotAccount1',
        'status': 'running',
        'script': {'name': 'Auto Woodcutting', 'running': true, 'runtime': 3600},
        'player': {
          'world': 301,
          'location': {'x': 3222, 'y': 3218},
          'hitpoints': 45,
          'prayer': 0,
          'runEnergy': 78,
        },
        'xp': {
          'totalGained': 12450,
          'perHour': 35000,
          'skills': {
            'woodcutting': {'current': 45, 'gained': 12450},
          },
        },
        'uptime': 3600,
        'loggedIn': true,
      };

      final status = BotStatus.fromJson(json);

      expect(status.version, 1);
      expect(status.status, 'running');
      expect(status.scriptName, 'Auto Woodcutting');
      expect(status.scriptRunning, true);
      expect(status.scriptRuntime, 3600);
      expect(status.world, 301);
      expect(status.hitpoints, 45);
      expect(status.prayer, 0);
      expect(status.runEnergy, 78);
      expect(status.totalXpGained, 12450);
      expect(status.xpPerHour, 35000);
      expect(status.uptime, 3600);
      expect(status.loggedIn, true);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'version': 1,
        'status': 'login_screen',
        'script': {'running': false, 'runtime': 0},
        'player': {},
        'xp': {'totalGained': 0, 'perHour': 0, 'skills': {}},
        'uptime': 10,
        'loggedIn': false,
      };

      final status = BotStatus.fromJson(json);

      expect(status.scriptName, isNull);
      expect(status.world, isNull);
      expect(status.hitpoints, 0);
      expect(status.loggedIn, false);
    });

    test('fromJson tolerates unknown fields (additive schema)', () {
      final json = {
        'version': 2,
        'status': 'running',
        'script': {'name': 'Test', 'running': true, 'runtime': 100},
        'player': {'world': 301},
        'xp': {'totalGained': 0, 'perHour': 0, 'skills': {}},
        'uptime': 100,
        'loggedIn': true,
        'newFieldFromFuture': 'should be ignored',
      };

      // Should not throw
      final status = BotStatus.fromJson(json);
      expect(status.version, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/config/services/bot_engine/bot_status_test.dart -v
```

Expected: FAIL — `BotStatus` class not found.

- [ ] **Step 3: Implement BotStatus**

Create `lib/config/services/bot_engine/bot_status.dart`:

```dart
/// Parsed response from the Microbot Status API (/status endpoint).
/// Tolerates unknown fields — additive-only schema per spec.
class BotStatus {
  final int version;
  final String status;
  final String? scriptName;
  final bool scriptRunning;
  final int scriptRuntime;
  final int? world;
  final int hitpoints;
  final int prayer;
  final int runEnergy;
  final int totalXpGained;
  final int xpPerHour;
  final Map<String, int> skillXpGained;
  final int uptime;
  final bool loggedIn;

  const BotStatus({
    required this.version,
    required this.status,
    this.scriptName,
    this.scriptRunning = false,
    this.scriptRuntime = 0,
    this.world,
    this.hitpoints = 0,
    this.prayer = 0,
    this.runEnergy = 0,
    this.totalXpGained = 0,
    this.xpPerHour = 0,
    this.skillXpGained = const {},
    this.uptime = 0,
    this.loggedIn = false,
  });

  factory BotStatus.fromJson(Map<String, dynamic> json) {
    final script = json['script'] as Map<String, dynamic>? ?? {};
    final player = json['player'] as Map<String, dynamic>? ?? {};
    final xp = json['xp'] as Map<String, dynamic>? ?? {};
    final skills = xp['skills'] as Map<String, dynamic>? ?? {};

    return BotStatus(
      version: json['version'] as int? ?? 1,
      status: json['status'] as String? ?? 'unknown',
      scriptName: script['name'] as String?,
      scriptRunning: script['running'] as bool? ?? false,
      scriptRuntime: script['runtime'] as int? ?? 0,
      world: player['world'] as int?,
      hitpoints: player['hitpoints'] as int? ?? 0,
      prayer: player['prayer'] as int? ?? 0,
      runEnergy: player['runEnergy'] as int? ?? 0,
      totalXpGained: xp['totalGained'] as int? ?? 0,
      xpPerHour: xp['perHour'] as int? ?? 0,
      skillXpGained: {
        for (final entry in skills.entries)
          if (entry.value is Map)
            entry.key: (entry.value as Map)['gained'] as int? ?? 0,
      },
      uptime: json['uptime'] as int? ?? 0,
      loggedIn: json['loggedIn'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/config/services/bot_engine/bot_status_test.dart -v
```

Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/bot_engine/bot_status.dart \
        test/config/services/bot_engine/bot_status_test.dart
git commit -m "feat(bot-engine): add BotStatus model for Status API response

Parses /status JSON: script info, player state, XP, uptime.
Tolerates unknown fields (additive-only schema, version field).
3 tests covering full parse, optional fields, and future schema."
```

---

### Task 9: MicrobotProfileWriter — Rename settings.properties to commandcenter.properties

**Files:**
- Modify: `lib/config/services/bot_engine/microbot_profile_writer.dart`
- Test: `test/config/services/bot_engine/microbot_profile_writer_test.dart`

**Context:** The spec says profile config should use `commandcenter.properties` (not `settings.properties`) to avoid conflicts with RuneLite's internal property loading. The Java-side AutoLoginPlugin and ScriptAutoStartPlugin read `commandcenter.properties`.

- [ ] **Step 1: Update the test expectations first**

In `test/config/services/bot_engine/microbot_profile_writer_test.dart`, change all references from `settings.properties` to `commandcenter.properties`:

```dart
// Line 34: Change 'settings.properties' to 'commandcenter.properties'
final settings = File(p.join(profileDir.path, 'commandcenter.properties'));
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/config/services/bot_engine/microbot_profile_writer_test.dart -v
```

Expected: FAIL — file `commandcenter.properties` not found (code still writes `settings.properties`).

- [ ] **Step 3: Update the profile writer**

In `lib/config/services/bot_engine/microbot_profile_writer.dart`, line 28:

Change:
```dart
await File(p.join(dir.path, 'settings.properties'))
```
To:
```dart
await File(p.join(dir.path, 'commandcenter.properties'))
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/config/services/bot_engine/microbot_profile_writer_test.dart -v
```

Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/bot_engine/microbot_profile_writer.dart \
        test/config/services/bot_engine/microbot_profile_writer_test.dart
git commit -m "refactor(profile-writer): rename settings.properties to commandcenter.properties

Avoids conflicts with RuneLite's internal settings.properties loading.
Java-side AutoLoginPlugin and ScriptAutoStartPlugin read commandcenter.properties."
```

---

### Task 10: MicrobotEngine — Update Launch Args and Add Port File Polling

**Files:**
- Modify: `lib/config/services/bot_engine/microbot_engine.dart`
- Modify: `lib/config/services/bot_engine/bot_engine.dart` (interface)
- Test: `test/config/services/bot_engine/microbot_engine_test.dart`

**Context:** Three changes: (1) replace `--profile=bot-<id>` with `--cc-profile-dir=<path>`, (2) add `--status-port-file=<path>/status.port`, (3) after process start, poll for `status.port` file (max 10s). The `launch()` return type changes to include the status port.

- [ ] **Step 1: Update test expectations for buildLaunchArgs**

In `test/config/services/bot_engine/microbot_engine_test.dart`, update the tests:

```dart
test('buildLaunchArgs constructs correct argument list with proxy', () {
  final engine = _makeEngine();
  final args = engine.buildLaunchArgs(
    characterId: 42,
    proxyUrl: 'socks5://user:pass@1.2.3.4:1080',
    config: const LaunchConfig(scriptName: 'Tutorial', jvmArgs: '-Xmx384m'),
  );
  expect(args[0], '-Xmx384m');
  expect(args[1], '-jar');
  expect(args[2], '/app/microbot-shaded.jar');
  expect(args, contains(startsWith('--cc-profile-dir=')));
  expect(args, contains(startsWith('--status-port-file=')));
  expect(args, contains('--proxy=socks5://user:pass@1.2.3.4:1080'));
  expect(args, contains('--safe-mode'));
  // Should NOT contain old --profile flag
  expect(args.any((a) => a.startsWith('--profile=')), isFalse);
});

test('buildLaunchArgs omits --proxy when proxyUrl is null', () {
  final engine = _makeEngine();
  final args = engine.buildLaunchArgs(characterId: 7, proxyUrl: null, config: const LaunchConfig(scriptName: 'Test'));
  expect(args.any((a) => a.startsWith('--proxy')), isFalse);
  expect(args, contains(startsWith('--cc-profile-dir=')));
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/config/services/bot_engine/microbot_engine_test.dart -v
```

Expected: FAIL — tests still expect `--profile=bot-42`.

- [ ] **Step 3: Update buildLaunchArgs**

In `lib/config/services/bot_engine/microbot_engine.dart`, replace the `buildLaunchArgs` method:

```dart
List<String> buildLaunchArgs({
  required int characterId,
  required String? proxyUrl,
  required LaunchConfig config,
}) {
  final args = <String>[];
  final jvmArgs = config.jvmArgs ?? '-Xmx512m';
  args.addAll(jvmArgs.split(' ').where((s) => s.isNotEmpty));
  args.addAll(['-jar', jarPath]);

  // Custom profile directory (replaces old --profile=bot-<id>)
  final profilePath = _profileWriter.profilePath(characterId: characterId);
  args.add('--cc-profile-dir=$profilePath');

  // Status API port file path
  args.add('--status-port-file=${p.join(profilePath, 'status.port')}');

  if (proxyUrl != null) {
    args.add('--proxy=$proxyUrl');
  }
  args.add('--safe-mode');
  if (config.advancedFlags.isNotEmpty) {
    args.addAll(config.advancedFlags.split(' ').where((s) => s.isNotEmpty));
  }
  return args;
}
```

Ensure `import 'package:path/path.dart' as p;` is at the top (already imported in the file).

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/config/services/bot_engine/microbot_engine_test.dart -v
```

Expected: ALL PASS.

- [ ] **Step 5: Update BotEngine interface to return status port**

In `lib/config/services/bot_engine/bot_engine.dart`, change return type:

```dart
/// Launch result containing PID and optional status port.
typedef LaunchResult = ({int pid, int? statusPort});

abstract class BotEngine {
  /// Launch a bot instance. Returns PID and optional status port.
  Future<LaunchResult> launch({
    required int characterId,
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,
    required LaunchConfig config,
  });

  Future<void> stop(int pid);
  String get engineName;
}
```

- [ ] **Step 6: Update MicrobotEngine.launch() with port file polling**

Replace the `launch()` method in `microbot_engine.dart`:

```dart
@override
Future<LaunchResult> launch({
  required int characterId,
  required String characterName,
  required String email,
  required String password,
  required String? proxyUrl,
  required LaunchConfig config,
}) async {
  await _profileWriter.writeProfile(
    characterId: characterId,
    email: email,
    password: password,
    world: config.world,
    scriptName: config.scriptName,
  );

  final args = buildLaunchArgs(characterId: characterId, proxyUrl: proxyUrl, config: config);

  logger.i('Launching Microbot for $characterName (id=$characterId)');

  final process = await Process.start(javaPath, args);
  final pid = process.pid;

  _activePids.add(pid);
  _pidToCharacterId[pid] = characterId;

  process.stdout.transform(const SystemEncoding().decoder).listen((data) {
    onLog('[Microbot:$characterName] ${_redactCredentials(data)}');
  });
  process.stderr.transform(const SystemEncoding().decoder).listen((data) {
    onLog('[Microbot:$characterName:ERR] ${_redactCredentials(data)}');
  });

  process.exitCode.then((_) {
    _activePids.remove(pid);
    _pidToCharacterId.remove(pid);
  });

  // Poll for status.port file (max 10s, 500ms intervals)
  final profilePath = _profileWriter.profilePath(characterId: characterId);
  final portFile = File(p.join(profilePath, 'status.port'));
  int? statusPort;
  for (int i = 0; i < 20; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
    if (portFile.existsSync()) {
      try {
        final content = portFile.readAsStringSync().trim();
        statusPort = int.tryParse(content);
        if (statusPort != null) {
          logger.i('Status API discovered on port $statusPort for $characterName');
          break;
        }
      } catch (_) {}
    }
  }

  return (pid: pid, statusPort: statusPort);
}
```

- [ ] **Step 7: Update callers of launch() — StatusController**

In `lib/feature/Status/controller/status_controller.dart`, update `launchCharacter()` to handle the new return type:

```dart
// Change line 136:
final result = await _botEngine!.launch(
  characterId: character.id!,
  characterName: character.name,
  email: account.email,
  password: account.password,
  proxyUrl: proxyUrl,
  config: config,
);

final tracked = TrackedClient(
  characterName: character.name,
  characterId: character.id!,
  accountId: account.id!,
  proxySlotId: account.proxySlotId,
  email: account.email,
  password: account.password,
  proxyUrl: proxyUrl,
  launchConfig: config,
  pid: result.pid,
  statusPort: result.statusPort,
  status: ClientStatus.running,
  launchedAt: DateTime.now(),
);
```

- [ ] **Step 8: Verify build**

```bash
flutter test
```

Expected: ALL PASS (may need to update other callers if any exist).

- [ ] **Step 9: Commit**

```bash
git add lib/config/services/bot_engine/bot_engine.dart \
        lib/config/services/bot_engine/microbot_engine.dart \
        lib/feature/Status/controller/status_controller.dart \
        test/config/services/bot_engine/microbot_engine_test.dart
git commit -m "feat(bot-engine): replace --profile with --cc-profile-dir, add port polling

buildLaunchArgs: --cc-profile-dir=<path>, --status-port-file=<path>.
launch(): polls for status.port file (max 10s, 500ms intervals).
BotEngine interface returns LaunchResult (pid + statusPort).
Updated StatusController to pass statusPort to TrackedClient."
```

---

### Task 11: Update WatchdogHandlers for LaunchResult and --cc-profile-dir

**Files:**
- Modify: `lib/config/services/watchdog/watchdog_handlers.dart`

**Context:** Three methods in WatchdogHandlers reference the old `--profile=bot-<id>` flag and the old `Future<int>` return type from `BotEngine.launch()`. All three must be updated to work with the new `LaunchResult` return type and `--cc-profile-dir` flag.

- [ ] **Step 1: Update handleRestart() to unpack LaunchResult**

In `lib/config/services/watchdog/watchdog_handlers.dart`, line 106:

Change:
```dart
final pid = await _botEngine.launch(
  characterId: client.characterId,
  characterName: client.characterName,
  email: client.email,
  password: client.password,
  proxyUrl: client.proxyUrl,
  config: client.launchConfig,
);
client.pid = pid;
```

To:
```dart
final result = await _botEngine.launch(
  characterId: client.characterId,
  characterName: client.characterName,
  email: client.email,
  password: client.password,
  proxyUrl: client.proxyUrl,
  config: client.launchConfig,
);
client.pid = result.pid;
client.statusPort = result.statusPort;
```

Also update the log message on line 118 to use `result.pid`:
```dart
logger.i(
    'Relaunched ${client.characterName} (PID: ${result.pid}, attempt ${client.retryCount}/${WatchdogService.maxRetries})');
```

- [ ] **Step 2: Update discoverPid() to match --cc-profile-dir**

Change `discoverPid()` (line 135-143):

```dart
int? discoverPid(TrackedClient client, List<ProcessClient> liveProcesses) {
  // Match the new --cc-profile-dir flag containing bot-<characterId>
  final profileArg = 'bot-${client.characterId}';
  for (final process in liveProcesses) {
    if (process.commandLine.contains('--cc-profile-dir=') &&
        process.commandLine.contains(profileArg)) {
      return process.processId;
    }
  }
  return null;
}
```

- [ ] **Step 3: Update recaptureRunningClients() regex**

Change the regex on line 171:

From:
```dart
final profileRegex = RegExp(r'--profile=bot-(\d+)');
```
To:
```dart
final profileRegex = RegExp(r'--cc-profile-dir=.*bot-(\d+)');
```

And line 174:
```dart
final profileMatch = profileRegex.firstMatch(process.commandLine);
```
(This line stays the same — the regex change handles the matching.)

- [ ] **Step 4: Verify build**

```bash
flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/watchdog/watchdog_handlers.dart
git commit -m "refactor(watchdog): update handlers for LaunchResult and --cc-profile-dir

handleRestart: unpacks LaunchResult record (pid + statusPort).
discoverPid: matches --cc-profile-dir instead of --profile.
recaptureRunningClients: updated regex for new flag format."
```

---

### Task 12: Update Integration Test

**Files:**
- Modify: `test/config/services/bot_engine/bot_engine_integration_test.dart`

**Context:** This test file checks for `settings.properties` (now `commandcenter.properties`) and `--profile=bot-42` (now `--cc-profile-dir`).

- [ ] **Step 1: Update file name assertion**

Line 45: change `settings.properties` to `commandcenter.properties`:

```dart
final settings = File(p.join(tempDir.path, 'bot-42', 'commandcenter.properties'));
```

- [ ] **Step 2: Update launch args assertion**

Line 105: change `--profile=bot-42` to match `--cc-profile-dir`:

```dart
expect(appFlags, contains(startsWith('--cc-profile-dir=')));
expect(appFlags, contains(startsWith('--status-port-file=')));
// Should NOT contain old --profile flag
expect(appFlags.any((a) => a.startsWith('--profile=')), isFalse);
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/config/services/bot_engine/bot_engine_integration_test.dart -v
```

Expected: ALL PASS.

- [ ] **Step 4: Commit**

```bash
git add test/config/services/bot_engine/bot_engine_integration_test.dart
git commit -m "test: update integration tests for commandcenter.properties and --cc-profile-dir"
```

---

### Task 13: TrackedClient — Add Status Fields

**Files:**
- Modify: `lib/config/services/watchdog/tracked_client.dart`

**Context:** Two new fields: `statusPort` (discovered from port file) and `lastStatus` (latest parsed Status API response).

- [ ] **Step 1: Add fields to TrackedClient**

In `lib/config/services/watchdog/tracked_client.dart`:

```dart
import 'package:command_center/config/services/bot_engine/bot_status.dart';

// Add to class fields (after pid):
int? statusPort;
BotStatus? lastStatus;

// Add to constructor parameters:
TrackedClient({
  // ... existing params ...
  this.statusPort,
  this.lastStatus,
}) : _discoveryMisses = 0;
```

- [ ] **Step 2: Verify build**

```bash
flutter test
```

Expected: ALL PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/watchdog/tracked_client.dart
git commit -m "feat(watchdog): add statusPort and lastStatus fields to TrackedClient

statusPort: discovered ephemeral port from status.port file.
lastStatus: latest parsed BotStatus from Status API polling."
```

---

### Task 14: WatchdogService — Add Status API Polling

**Files:**
- Modify: `lib/config/services/watchdog/watchdog_service.dart`

**Context:** After the existing PID liveness check, if `statusPort != null`, fetch `GET http://127.0.0.1:{statusPort}/status` with a 2-second timeout. Parse into `BotStatus`, store in `client.lastStatus`. On failure: set `lastStatus = null`, continue with PID-only monitoring.

- [ ] **Step 1: Add status polling to _tick()**

In `lib/config/services/watchdog/watchdog_service.dart`, add import:

```dart
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:command_center/config/services/bot_engine/bot_status.dart';
```

After the PID liveness check (after `continue;` on line 176), add the status enrichment:

```dart
// Status API enrichment — fetch rich state if port is known
if (client.statusPort != null) {
  try {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2);
    final request = await httpClient
        .getUrl(Uri.parse('http://127.0.0.1:${client.statusPort}/status'))
        .timeout(const Duration(seconds: 2));
    final response = await request.close()
        .timeout(const Duration(seconds: 2));
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      client.lastStatus = BotStatus.fromJson(
          jsonDecode(body) as Map<String, dynamic>);
      changed = true;
    } else {
      client.lastStatus = null;
    }
    httpClient.close();
  } catch (_) {
    // Status API unavailable — fall back to PID-only monitoring
    client.lastStatus = null;
  }
}
```

This block goes inside the `for (final client in trackedClients.values.toList())` loop, specifically in the branch where `livePids.contains(client.pid)` is true (the process is alive), right before the `continue;` statement.

- [ ] **Step 2: Verify build**

```bash
flutter test
```

Expected: ALL PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/watchdog/watchdog_service.dart
git commit -m "feat(watchdog): add Status API polling in tick loop

Fetches GET /status from 127.0.0.1:{statusPort} with 2s timeout.
Parses into BotStatus, stores in TrackedClient.lastStatus.
Falls back to PID-only monitoring on any failure."
```

---

### Task 15: Integration Test — Full Launch Cycle Verification

**Context:** Verify the full chain works: profile writer creates `commandcenter.properties`, engine passes `--cc-profile-dir` and `--status-port-file`, tests still pass.

- [ ] **Step 1: Run full test suite**

```bash
cd /mnt/c/Projects/command_center
flutter test
```

Expected: All tests pass.

- [ ] **Step 2: Push and create PR to dev**

```bash
git push origin dev
```

Or create a PR if working on a feature branch.

---

## Summary

| Task | Repo | Type | Files |
|------|------|------|-------|
| 1. StatusApiServer | Microbot | Java | `StatusApiServer.java` |
| 2. StatusApiHandler | Microbot | Java | `StatusApiHandler.java` |
| 3. BotStatusModel | Microbot | Java | `BotStatusModel.java` |
| 4. Wire into MicrobotPlugin | Microbot | Java | `MicrobotPlugin.java` |
| 5. CLI flags | Microbot | Java | RuneLite args class |
| 6. AutoLoginPlugin | Microbot | Java | `AutoLoginPlugin.java` |
| 7. ScriptAutoStartPlugin | Microbot | Java | `ScriptAutoStartPlugin.java` |
| 8. BotStatus Dart model | Command Center | Feature (TDD) | `bot_status.dart` + test |
| 9. Profile writer rename | Command Center | Refactor (TDD) | `microbot_profile_writer.dart` + test |
| 10. Engine launch args + port polling | Command Center | Feature (TDD) | `microbot_engine.dart` + `bot_engine.dart` + test |
| 11. WatchdogHandlers update | Command Center | Refactor | `watchdog_handlers.dart` |
| 12. Integration test update | Command Center | Test | `bot_engine_integration_test.dart` |
| 13. TrackedClient fields | Command Center | Feature | `tracked_client.dart` |
| 14. WatchdogService polling | Command Center | Feature | `watchdog_service.dart` |
| 15. Integration verification | Command Center | Verification | — |
