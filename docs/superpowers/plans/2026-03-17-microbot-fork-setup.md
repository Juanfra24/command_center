# Microbot Fork Setup, Security Hardening & Build Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a private, security-hardened fork of Microbot with a CI/CD pipeline that produces custom shaded JARs, and update Command Center to download from the private fork.

**Architecture:** Fork `chsami/Microbot` to `Juanfra24/Microbot` (private). Strip ~140 community scripts, remove all telemetry/analytics/external calls, add credential redaction. GitHub Actions builds shaded JARs on push to `main`. Command Center authenticates via GitHub PAT stored in AppConfigService.

**Tech Stack:** Java 17, Gradle, GitHub Actions, Dart/Flutter (Command Center side), `flutter_test`

**Spec:** `docs/superpowers/specs/2026-03-17-microbot-fork-and-scripts-design.md` (Parts 1, 2, 5 — partial)

**Scope note:** This plan covers Parts 1 (Fork Setup), 2 (Security Hardening), and the **build pipeline + JAR downloader** portions of Part 5. The remaining Part 5 Dart-side changes — MicrobotProfileWriter rename (`settings.properties` → `commandcenter.properties`), MicrobotEngine launch args (`--cc-profile-dir`, `--status-port-file`), status port polling, TrackedClient fields (`statusPort`, `lastStatus`), WatchdogService status enrichment, and the BotStatus Dart model — are **deferred to Plan 2** because they depend on the Java-side Status API (Part 3) and Auto-Login/Auto-Start (Part 4) being implemented first.

---

## Chunk 1: Repository Setup & Script Cleanup

### Task 1: Fork Repository & Set Up Branches

This task is performed on GitHub and via git CLI. No Dart code changes.

**Context:** The fork lives at `Juanfra24/Microbot` (private). Three branches: `upstream-tracking` (clean mirror), `main` (production + CI), `dev` (working branch). The upstream remote points to `chsami/Microbot`.

- [ ] **Step 1: Fork on GitHub**

Go to `github.com/chsami/Microbot` → Fork → Owner: `Juanfra24` → Repository name: `Microbot` → **Uncheck** "Copy the main branch only" → Create fork. Then set the repo to **Private** in Settings → General → Danger Zone → Change visibility.

- [ ] **Step 2: Clone and set up remotes**

```bash
cd /mnt/c/Projects
git clone git@github.com:Juanfra24/Microbot.git
cd Microbot
git remote add upstream https://github.com/chsami/Microbot.git
git remote -v
# origin    git@github.com:Juanfra24/Microbot.git (fetch/push)
# upstream  https://github.com/chsami/Microbot.git (fetch/push)
```

- [ ] **Step 3: Create branch structure**

```bash
# upstream-tracking: clean mirror of chsami/Microbot:main
git checkout -b upstream-tracking origin/main
git push -u origin upstream-tracking

# dev: working branch
git checkout -b dev origin/main
git push -u origin dev

# main already exists from fork
git checkout main
```

- [ ] **Step 4: Verify branches**

```bash
git branch -a
# Expected: main, dev, upstream-tracking + remotes
```

- [ ] **Step 5: Document upstream sync workflow**

Create `docs/upstream-sync.md` in the fork repo with the manual sync procedure:

```markdown
# Upstream Sync Workflow

Manual procedure to pull updates from `chsami/Microbot` into our fork.

## Steps

1. `git fetch upstream` — fetch latest from chsami/Microbot
2. `git checkout upstream-tracking`
3. `git merge upstream/main` — fast-forward mirror
4. `git checkout dev`
5. `git merge upstream-tracking` — bring upstream changes into dev
6. Resolve conflicts, test build: `./gradlew :runelite-client:build -x test`
7. PR dev → main — triggers release build

## Conflict minimization

All our custom code lives under `commandcenter/`. Upstream never touches this directory.
Conflicts are limited to:
- Files modified for security (telemetry removal)
- Build config (gradle files)
- Kept upstream scripts (if upstream modifies them)

## Future automation

A `upstream-sync.yml` GitHub Action can automate steps 1-5: periodically fetch
upstream, attempt merge into a `sync/upstream-<date>` branch, and open a PR to
`dev` if it succeeds (or alert if conflicts exist).
```

```bash
git add docs/upstream-sync.md
git commit -m "docs: add upstream sync workflow documentation"
```

- [ ] **Step 6: Verify setup**

No further commit needed — branch creation and documentation are the deliverables.

---

### Task 2: Delete Community Scripts (Keep ~10 Curated)

**Files:**
- Delete: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/` — all script directories EXCEPT the curated list below
- Keep: `example/`, `util/antiban/`, `breakhandler/`, and the specific scripts listed

**Context:** Microbot ships with ~150 scripts. We keep ~10 for reference and function, delete the rest. This reduces JAR size, merge conflict surface, and attack surface. The `commandcenter/` directory (our custom code) doesn't exist yet — it will be created in Plan 2.

- [ ] **Step 1: Identify scripts to keep**

Run from the Microbot repo root:

```bash
# List all top-level directories under the plugins/microbot/ path
ls -d runelite-client/src/main/java/net/runelite/client/plugins/microbot/*/
```

Keep these directories (exact names may vary — verify on fork):
- `example/` — reference template
- `tutorialisland/` — Tutorial Island script
- `fighter/` or `aiofighter/` — AIO Fighter
- `woodcutting/` — Auto Woodcutting
- `mining/` — Auto Mining
- `fishing/` — Fishing
- `cooking/` — Auto Cooking
- `thieving/` — Thieving
- `breakhandler/` — Break Handler
- `util/` — Utility package (contains antiban, Rs2* helpers — MUST keep)
- `Microbot.java`, `MicrobotPlugin.java`, `MicrobotApi.java`, etc. — core files (not directories, keep all loose Java files)

- [ ] **Step 2: Generate the exact delete list**

```bash
cd runelite-client/src/main/java/net/runelite/client/plugins/microbot/

# List all directories, then filter out the keep list
ls -d */ | sort > /tmp/all_scripts.txt

# Keep list (one per line):
cat > /tmp/keep_scripts.txt << 'EOF'
example/
tutorialisland/
fighter/
woodcutting/
mining/
fishing/
cooking/
thieving/
breakhandler/
util/
EOF

# Generate delete list
comm -23 /tmp/all_scripts.txt /tmp/keep_scripts.txt > /tmp/delete_scripts.txt
cat /tmp/delete_scripts.txt
```

Review the delete list. If any directory names from Step 1 don't match (e.g. `aiofighter/` instead of `fighter/`), update the keep list and regenerate.

- [ ] **Step 3: Execute deletions**

```bash
cd runelite-client/src/main/java/net/runelite/client/plugins/microbot/

# Delete each directory in the delete list
xargs -I{} rm -rf {} < /tmp/delete_scripts.txt

# Verify kept directories still exist
ls -d example/ util/ breakhandler/
```

- [ ] **Step 4: Verify build still compiles**

```bash
cd /mnt/c/Projects/Microbot
./gradlew :runelite-client:compileJava
```

Expected: BUILD SUCCESSFUL. If there are compilation errors from deleted imports, fix them (remove import statements in kept files that reference deleted scripts).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: delete ~140 community scripts, keep curated 10

Kept: example, tutorial island, AIO fighter, woodcutting, mining,
fishing, cooking, thieving, break handler, util (antiban + Rs2 helpers).

Reduces JAR size, merge conflict surface, and attack surface."
```

---

## Chunk 2: Security Hardening

### Task 3: Security Audit — Find All Outbound Calls

**Context:** Before removing anything, we systematically find all outbound HTTP/WebSocket calls in the codebase. Each hit is classified as Game-essential (keep), Our code (keep), or Remove.

- [ ] **Step 1: Run HTTP client grep**

```bash
cd /mnt/c/Projects/Microbot
grep -rn "HttpClient\|URLConnection\|HttpURLConnection\|OkHttpClient\|WebSocket\|HttpRequest\|HttpResponse" \
  --include="*.java" \
  runelite-client/src/main/java/ > /tmp/microbot-http-audit.txt
cat /tmp/microbot-http-audit.txt
```

- [ ] **Step 2: Run analytics/telemetry grep**

```bash
grep -rn "discord\|webhook\|analytics\|telemetry\|tracking\|phone.home\|version.check" \
  --include="*.java" -i \
  runelite-client/src/main/java/ > /tmp/microbot-telemetry-audit.txt
cat /tmp/microbot-telemetry-audit.txt
```

- [ ] **Step 3: Run external URL grep**

```bash
grep -rn "https\?://" --include="*.java" \
  runelite-client/src/main/java/net/runelite/client/plugins/microbot/ > /tmp/microbot-urls-audit.txt
cat /tmp/microbot-urls-audit.txt
```

- [ ] **Step 4: Classify each hit**

For each file/line found, add a classification comment in a local audit doc:

```
File: path/to/File.java:line
Call: HttpClient.newHttpClient().send(...)
Target: https://some-api.com/...
Classification: REMOVE | KEEP (game-essential) | KEEP (RuneLite core) | VERIFY
```

Save to `docs/security-audit.md` in the fork repo.

- [ ] **Step 5: Commit audit document**

```bash
git add docs/security-audit.md
git commit -m "docs: add security audit of outbound network calls"
```

---

### Task 4: Remove Telemetry & External Call Files

**Files to remove/modify** (verify exact paths on fork):
- Remove: `MicrobotVersionChecker.java` — phones home for updates
- Remove: `RandomFactClient.java` — external API calls
- Remove: Discord notifier under `util/discord/` — webhook calls
- Verify & remove: `GameChatAppender.java` — if it phones home
- Verify & remove: `Chatbot` plugin — OpenAI API calls
- Verify & modify: `MicrobotRSConfig.java` — if it phones home for remote config
- Verify & modify: `MicrobotApi.java` — audit for external calls, remove if found
- Modify: `MicrobotPlugin.java` — remove startup telemetry
- Modify: RuneLite core analytics (disable built-in telemetry)

**Context:** Each file marked "Verify" in the spec must be resolved to a definitive Remove/Keep during this task. The audit from Task 3 guides these decisions.

- [ ] **Step 1: Remove definitive files**

```bash
cd /mnt/c/Projects/Microbot

# Remove MicrobotVersionChecker (phones home)
find . -name "MicrobotVersionChecker.java" -type f
# Delete it
rm <path-to-MicrobotVersionChecker.java>

# Remove RandomFactClient (external API)
find . -name "RandomFactClient.java" -type f
rm <path-to-RandomFactClient.java>

# Remove Discord notifier
find . -path "*/discord/*" -name "*.java" -type f
rm -rf <path-to-discord-directory>
```

- [ ] **Step 2: Verify & resolve conditional files**

For each file marked "Verify on fork":

```bash
# GameChatAppender — check if it phones home
grep -n "http\|url\|send\|post\|webhook" <path-to-GameChatAppender.java> -i
# If it phones home → delete. If purely local logging → keep.

# Chatbot plugin — check for OpenAI API calls
find . -name "*Chatbot*" -o -name "*chatbot*" | head -20
grep -n "openai\|api.key\|gpt\|completion" <path-to-chatbot> -i
# If found → delete entire plugin directory.

# MicrobotRSConfig — check for remote config fetch
grep -n "http\|url\|fetch\|remote\|download" <path-to-MicrobotRSConfig.java> -i
# If it phones home → strip the fetch, keep local config.
# If purely local → keep as-is.

# MicrobotApi — check for external calls
find . -name "MicrobotApi.java" -type f
grep -n "http\|url\|send\|post\|webhook\|external" <path-to-MicrobotApi.java> -i
# If it makes external calls → remove those calls, keep game-essential methods.
```

- [ ] **Step 3: Fix compilation errors from removals**

```bash
# Find all references to removed classes
grep -rn "MicrobotVersionChecker\|RandomFactClient\|Discord" \
  --include="*.java" runelite-client/src/main/java/
# Remove/comment out these references
```

- [ ] **Step 4: Clean up MicrobotPlugin.java startup**

Open `MicrobotPlugin.java`, find `startUp()` method. Remove any:
- Version check calls
- Analytics initialization
- External service pings
- Discord webhook setup

Keep: Core plugin initialization, script system startup, UI initialization.

Document what was removed in the commit message (not just "removed telemetry" — list specific methods/calls).

- [ ] **Step 5: Disable RuneLite core telemetry**

```bash
# Find RuneLite's built-in telemetry
grep -rn "telemetry\|analytics\|tracking\|metrics" \
  --include="*.java" \
  runelite-client/src/main/java/net/runelite/client/ | grep -v "plugins/microbot"
```

For each hit in RuneLite core: disable the call (comment out or remove). Be careful to keep game-essential functionality.

- [ ] **Step 6: Verify build compiles**

```bash
./gradlew :runelite-client:compileJava
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "security: remove telemetry, analytics, and external calls

Removed: MicrobotVersionChecker, RandomFactClient, Discord notifier.
Verified and resolved: GameChatAppender, Chatbot, MicrobotRSConfig.
Stripped startup telemetry from MicrobotPlugin.
Disabled RuneLite core analytics.

Bot now only connects to: Jagex game servers, localhost, RuneLite cache."
```

---

### Task 5: Add Credential Redaction in Java Logging

**Files:**
- Create: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/CredentialRedactor.java`

**Context:** Passwords must never appear in Java-side stdout/stderr. This complements the Dart-side `_redactCredentials` in `MicrobotEngine`. The `commandcenter/` package is our isolated namespace — all custom code lives here.

- [ ] **Step 1: Create commandcenter package directory**

```bash
mkdir -p runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/
```

- [ ] **Step 2: Create CredentialRedactor.java**

```java
package net.runelite.client.plugins.microbot.commandcenter;

import java.util.regex.Pattern;

/**
 * Utility to strip credentials from log messages.
 * Used by any logging path that might include profile data.
 */
public final class CredentialRedactor {
    private static final Pattern CREDENTIAL_PATTERN =
        Pattern.compile("password=\\S+", Pattern.CASE_INSENSITIVE);
    private static final Pattern EMAIL_PATTERN =
        Pattern.compile("email=\\S+@\\S+", Pattern.CASE_INSENSITIVE);

    private CredentialRedactor() {}

    public static String redact(String msg) {
        if (msg == null) return null;
        String result = CREDENTIAL_PATTERN.matcher(msg).replaceAll("password=***");
        result = EMAIL_PATTERN.matcher(result).replaceAll("email=***");
        return result;
    }
}
```

- [ ] **Step 3: Add unit test for CredentialRedactor**

Create `runelite-client/src/test/java/net/runelite/client/plugins/microbot/commandcenter/CredentialRedactorTest.java`:

```java
package net.runelite.client.plugins.microbot.commandcenter;

import org.junit.Test;
import static org.junit.Assert.*;

public class CredentialRedactorTest {
    @Test
    public void testRedactsPassword() {
        String input = "Login with password=secret123 on world 301";
        String result = CredentialRedactor.redact(input);
        assertEquals("Login with password=*** on world 301", result);
    }

    @Test
    public void testRedactsEmail() {
        String input = "email=user@example.com logged in";
        String result = CredentialRedactor.redact(input);
        assertEquals("email=*** logged in", result);
    }

    @Test
    public void testNoCredentials() {
        String input = "Normal log message";
        assertEquals("Normal log message", CredentialRedactor.redact(input));
    }

    @Test
    public void testNullInput() {
        assertNull(CredentialRedactor.redact(null));
    }
}
```

Run: `./gradlew :runelite-client:test --tests "*CredentialRedactorTest" -v`

- [ ] **Step 4: Wire redactor into logging paths**

Search for logging calls that might include credential data:

```bash
grep -rn "log\.\|logger\.\|System\.out\|System\.err" \
  --include="*.java" \
  runelite-client/src/main/java/net/runelite/client/plugins/microbot/ \
  | grep -i "password\|credential\|email\|login"
```

For each hit, wrap the log message with `CredentialRedactor.redact(...)`.

- [ ] **Step 5: Verify build**

```bash
./gradlew :runelite-client:compileJava
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "security: add credential redaction for Java-side logging

CredentialRedactor strips password= and email= from log messages.
Wired into all logging paths that might include profile data.
Unit test: CredentialRedactorTest (4 tests)."
```

---

### Task 6: Update .gitignore for Profile Directories

**Files:**
- Modify: `.gitignore` (repo root)

- [ ] **Step 1: Add profile directory exclusions**

Append to `.gitignore`:

```
# Command Center bot profiles (contain credentials)
bot-*/
microbot_profiles/
**/credentials.properties
**/status.port
```

- [ ] **Step 2: Verify no profile files are tracked**

```bash
git ls-files | grep -i "credentials\|bot-\|status\.port"
# Expected: no output
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore bot profile directories and credential files"
```

---

## Chunk 3: Build Pipeline & Dart Integration

### Task 7: GitHub Actions Build Workflow

**Files:**
- Create: `.github/workflows/build.yml`

**Context:** Trigger on push to `main`. Builds shaded JAR with Java 17, creates GitHub Release with semantic version tag. The JAR asset name must match `*-shaded.jar` so `MicrobotJarDownloader.findShadedJarUrl()` works unchanged.

- [ ] **Step 1: Create workflow file**

```yaml
# .github/workflows/build.yml
name: Build & Release

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Build shaded JAR
        run: ./gradlew :runelite-client:build -x test

      - name: Find shaded JAR
        id: find_jar
        run: |
          JAR_PATH=$(find runelite-client/build/libs -name "*-shaded.jar" | head -1)
          JAR_NAME=$(basename "$JAR_PATH")
          echo "jar_path=$JAR_PATH" >> "$GITHUB_OUTPUT"
          echo "jar_name=$JAR_NAME" >> "$GITHUB_OUTPUT"

      - name: Generate version tag
        id: version
        run: |
          # Semantic versioning: v1.0.N (patch increments per build)
          LATEST=$(gh release list --limit 1 --json tagName -q '.[0].tagName' 2>/dev/null || echo "v1.0.0")
          if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
            VERSION="v1.0.1"
          else
            PATCH=$(echo "$LATEST" | sed 's/v[0-9]*\.[0-9]*\.//')
            NEXT=$((PATCH + 1))
            VERSION="v1.0.$NEXT"
          fi
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
        env:
          GH_TOKEN: ${{ github.token }}

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.version.outputs.version }}
          name: Release ${{ steps.version.outputs.version }}
          files: ${{ steps.find_jar.outputs.jar_path }}
          generate_release_notes: true
```

- [ ] **Step 2: Verify workflow syntax**

```bash
# If you have actionlint installed:
actionlint .github/workflows/build.yml

# Otherwise just check YAML validity:
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build.yml'))"
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/build.yml
git commit -m "ci: add GitHub Actions build & release workflow

Builds shaded JAR on push to main, creates GitHub Release.
Uses semantic versioning: v1.0.N (patch increments per build).
JAR asset name matches *-shaded.jar for MicrobotJarDownloader."
```

---

### Task 8: Dart — Add GitHub PAT to AppConfigService

**Files:**
- Modify: `lib/config/services/app_config_service.dart`
- Test: `test/config/services/app_config_service_test.dart`

**Context:** The GitHub PAT is stored alongside existing API keys (Webshare, IPQS). `MicrobotJarDownloader` reads it to authenticate with the private repo's releases API. If the token is missing, the downloader skips download and uses a cached JAR.

- [ ] **Step 1: Write the failing tests**

Add to `test/config/services/app_config_service_test.dart` (inside the existing `main()`, after the last group):

```dart
group('AppConfigService - GitHub PAT', () {
  test('getGithubPat returns null when repo not initialized', () async {
    final result = await service.getGithubPat();
    expect(result, isNull);
  });

  test('saveGithubPat is no-op when repo not initialized', () async {
    // Should not throw — null-safe call does nothing
    await service.saveGithubPat('ghp_test123');
    // Still null because repo is not initialized
    final result = await service.getGithubPat();
    expect(result, isNull);
  });
});
```

Note: These tests follow the existing pattern — the service is created without a `ConfigRepository`, so `_configRepository?.getValue()` returns null and `_configRepository?.setValue()` is a no-op. Full integration tests with an in-memory database are a separate concern.

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /mnt/c/Projects/command_center
flutter test test/config/services/app_config_service_test.dart -v
```

Expected: FAIL — `getGithubPat` and `saveGithubPat` not defined on `AppConfigService`.

- [ ] **Step 3: Implement getGithubPat / saveGithubPat**

In `lib/config/services/app_config_service.dart`, add the key constant and methods:

```dart
// Add to config keys section (around line 23):
static const String _keyGithubPat = 'github_pat';

// Add methods (after saveMicrobotJavaPath, around line 268):

/// Get GitHub Personal Access Token for private repo access
Future<String?> getGithubPat() async {
  return _configRepository?.getValue(_keyGithubPat);
}

/// Save GitHub Personal Access Token
Future<void> saveGithubPat(String token) async {
  await _configRepository?.setValue(_keyGithubPat, token);
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/config/services/app_config_service_test.dart -v
```

Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/app_config_service.dart \
        test/config/services/app_config_service_test.dart
git commit -m "feat(config): add GitHub PAT storage for private repo access

New methods: getGithubPat(), saveGithubPat().
Stored in AppConfigTable as 'github_pat'.
Used by MicrobotJarDownloader to authenticate with private fork."
```

---

### Task 9: Dart — Update MicrobotJarDownloader for Private Repo

**Files:**
- Modify: `lib/config/services/bot_engine/microbot_jar_downloader.dart`
- Test: `test/config/services/bot_engine/microbot_jar_downloader_test.dart`

**Context:** Two changes: (1) point `_releasesUrl` to `Juanfra24/Microbot`, (2) add `Authorization: Bearer <token>` header to `_fetchLatestRelease()`. If no token is configured, skip download and fall back to cached JAR.

- [ ] **Step 1: Update `_releasesUrl`**

In `lib/config/services/bot_engine/microbot_jar_downloader.dart`, line 13-14:

```dart
// Change from:
static const _releasesUrl =
    'https://api.github.com/repos/chsami/Microbot/releases/latest';

// To:
static const _releasesUrl =
    'https://api.github.com/repos/Juanfra24/Microbot/releases/latest';
```

- [ ] **Step 2: Add Bearer token to _fetchLatestRelease**

Modify `_fetchLatestRelease()` to accept and use a token:

```dart
Future<Map<String, dynamic>> _fetchLatestRelease() async {
  final token = await _appConfig.getGithubPat();
  if (token == null || token.isEmpty) {
    throw Exception('GitHub PAT not configured — cannot access private repo');
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.getUrl(Uri.parse(_releasesUrl));
    request.headers.set('Accept', 'application/vnd.github+json');
    request.headers.set('Authorization', 'Bearer $token');
    final response = await request.close();

    if (response.statusCode == 401) {
      throw Exception('GitHub PAT invalid or expired');
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw Exception('GitHub API rate limited');
    }
    if (response.statusCode == 404) {
      throw Exception('Release not found — check repo URL and PAT permissions');
    }

    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}
```

- [ ] **Step 3: Add token auth to JAR download in ensureJar()**

Replace the download section (lines 65-97 of current source) with:

```dart
    // Download the JAR
    final jarPath = p.join(microbotDir, 'microbot-shaded.jar');
    final token = await _appConfig.getGithubPat();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      // Private repo assets require Bearer token + octet-stream accept
      if (token != null && token.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $token');
        request.headers.set('Accept', 'application/octet-stream');
      }
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'JAR download failed with HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var downloadedBytes = 0;

      final file = File(jarPath).openWrite();
      try {
        await for (final chunk in response) {
          file.add(chunk);
          downloadedBytes += chunk.length;
          onProgress?.call(downloadedBytes, totalBytes);
        }
      } finally {
        await file.close();
      }
    } catch (e) {
      logger.e('Failed to download Microbot JAR: $e');
      // Clean up partial download on failure
      final partial = File(jarPath);
      if (partial.existsSync()) await partial.delete();
      return existingPath;
    } finally {
      client.close();
    }
```

**Behavior change note:** The downloader now requires a GitHub PAT to access releases. Without a PAT, `_fetchLatestRelease()` throws immediately, and `ensureJar()` catches the exception and falls back to the cached JAR. This is intentional — the private fork's API returns 404 for unauthenticated requests.

- [ ] **Step 4: Update existing tests**

The existing tests for `findShadedJarUrl` and `isUpdateAvailable` are static methods — they don't need changes. No new HTTP-level tests needed since `_fetchLatestRelease` makes real HTTP calls (integration concern).

- [ ] **Step 5: Run all tests**

```bash
flutter test test/config/services/bot_engine/microbot_jar_downloader_test.dart -v
```

Expected: ALL PASS (existing static method tests unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/config/services/bot_engine/microbot_jar_downloader.dart
git commit -m "feat(bot-engine): point JAR downloader to private fork with PAT auth

Changed releases URL to Juanfra24/Microbot.
Added Bearer token auth from AppConfigService.getGithubPat().
Handles 401 (bad token), 404 (no release), 403/429 (rate limit).
Falls back to cached JAR when PAT is not configured."
```

---

### Task 10: Build Fork JAR & Verify

**Context:** This is the integration verification. Build the shaded JAR from the hardened fork, verify it compiles, and confirm no unexpected outbound connections.

- [ ] **Step 1: Build the shaded JAR locally**

```bash
cd /mnt/c/Projects/Microbot
./gradlew :runelite-client:build -x test
```

Expected: BUILD SUCCESSFUL. Find the JAR:

```bash
ls -la runelite-client/build/libs/*-shaded.jar
```

- [ ] **Step 2: Verify JAR runs**

```bash
java -jar runelite-client/build/libs/client-*-shaded.jar --safe-mode
```

Expected: Microbot launches (will show login screen). Close it after confirming it starts.

- [ ] **Step 3: Document network verification steps**

Create `docs/network-verification.md` in the fork:

```markdown
# Network Verification

## Allowed outbound connections
1. Jagex game servers (*.jagex.com, *.runescape.com)
2. localhost (127.0.0.1 — Status API, future)
3. RuneLite cache (repo.runelite.net — map data, item icons)

## How to verify
1. Build the shaded JAR: `./gradlew :runelite-client:build -x test`
2. Launch with Wireshark/tcpdump capturing
3. Confirm only the above destinations appear
4. Check for absence of: discord.com, any analytics domains, openai.com

## Audit history
- Initial audit: [date] — see docs/security-audit.md
```

- [ ] **Step 4: Push dev branch and create PR to main**

```bash
git push origin dev
gh pr create --title "Fork setup: security hardening & build pipeline" \
  --body "$(cat <<'EOF'
## Summary
- Deleted ~140 community scripts (kept 10 curated)
- Security audit: removed all telemetry, analytics, external calls
- Added credential redaction (CredentialRedactor.java)
- Added .gitignore for profile directories
- Added GitHub Actions build & release workflow
- Documented network verification steps

## Files removed
- MicrobotVersionChecker.java
- RandomFactClient.java
- Discord notifier (util/discord/)
- [Other files from audit]

## Test plan
- [ ] `./gradlew :runelite-client:build -x test` passes
- [ ] JAR launches with `--safe-mode`
- [ ] No unexpected outbound connections
EOF
)"
```

- [ ] **Step 5: Merge PR (triggers first CI build)**

After CI passes, merge the PR. This triggers the `build.yml` workflow and creates the first GitHub Release with the shaded JAR.

- [ ] **Step 6: Verify release exists**

```bash
gh release list --repo Juanfra24/Microbot --limit 1
# Expected: v1.0.1  (first semantic version release)
```

---

### Task 11: Run Command Center Tests

**Context:** Verify all existing tests still pass after the Dart-side changes (Tasks 8-9).

- [ ] **Step 1: Run full test suite**

```bash
cd /mnt/c/Projects/command_center
flutter test
```

Expected: All tests pass (including new GitHub PAT tests).

- [ ] **Step 2: Commit any test fixes**

If any tests broke due to the changes, fix and commit:

```bash
git add -A
git commit -m "fix(test): update tests for private repo changes"
```

---

## Summary

| Task | Repo | Type | Files |
|------|------|------|-------|
| 1. Fork & branches | Microbot (GitHub) | Setup | — |
| 2. Delete scripts | Microbot | Cleanup | ~140 script directories |
| 3. Security audit | Microbot | Audit | `docs/security-audit.md` |
| 4. Remove telemetry | Microbot | Security | 5-8 Java files |
| 5. Credential redaction | Microbot | Security | `CredentialRedactor.java` |
| 6. .gitignore | Microbot | Config | `.gitignore` |
| 7. GitHub Actions | Microbot | CI/CD | `.github/workflows/build.yml` |
| 8. GitHub PAT | Command Center | Feature (TDD) | `app_config_service.dart` + test |
| 9. JAR downloader auth | Command Center | Feature | `microbot_jar_downloader.dart` |
| 10. Build & verify | Microbot | Integration | Build + network verify |
| 11. Run CC tests | Command Center | Verification | — |
