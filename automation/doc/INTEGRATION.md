# Integrating the `in_app_automation` package into a Flutter project

This document is an **actionable checklist**. Work through the steps in order and
apply each file change to the target app. Every step names the file to edit and
the exact change to make. Code uses the real v0.2.0 API.

> Audience: the app you want to test (the "consumer project"), not the
> `in_app_automation` package itself.

---

## 0. Requirements the project must meet

- **Flutter ≥ 3.24.0**, Dart SDK `^3.5.3`.
- Supported targets today: **Android, iOS** (debug/profile). Web/desktop are
  untested.
- The app must be a normal Flutter app with a `MaterialApp` (or
  `MaterialApp.router`) at its root.
- Interactive widgets you plan to drive should be **reachable, enabled, and
  visible** — the engine dispatches real hit-tested input, so a widget behind a
  barrier, disabled, off-screen, or at `Opacity(0)` is (correctly) reported as
  not actionable.

---

## 1. Add the dependency — `pubspec.yaml`

Add `in_app_automation` under `dependencies`. Use whichever source applies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Local path (monorepo / not yet published):
  in_app_automation:
    path: ../automation
  # …or from git:
  # automation:
  #   git:
  #     url: https://your.git/host/automation.git
```

Add the integration-test harness under `dev_dependencies` (needed for headless
CI in step 6):

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

Then run `flutter pub get`.

---

## 2. Wrap the app — `lib/main.dart`

Wrap the root widget with `AutomationInspectorWrapper` and register the tests
**only in debug** so test code and any credentials never ship in a release
binary.

```dart
import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:flutter/material.dart';
import 'package:in_app_automation/in_app_automation.dart';

import 'automation/app_tests.dart'; // created in step 3

void main() {
  if (kDebugMode) {
    registerAutomationTests();
  }
  runApp(
    AutomationInspectorWrapper(
      child: const MyApp(),
    ),
  );
}
```

The overlay renders only in debug builds; in release it is absent and actuation
is disabled (see step 8).

---

## 3. Create the test file — `lib/automation/app_tests.dart`

Keep scenarios in one place. Register before `runApp`. Use `tags`, `timeout`,
and `retries` as needed, and hooks for isolation.

```dart
import 'package:in_app_automation/in_app_automation.dart';

void registerAutomationTests() {
  final registry = AutomationRegistry.instance;

  // Runs before EVERY test — the place to reset app state for isolation.
  registry.beforeEach(() async {
    // e.g. sign out, clear caches, navigate to the root route.
  });

  registry.registerTest(
    name: 'Login flow',
    tags: {'smoke'},
    timeout: const Duration(seconds: 20),
    retries: 1,
    steps: [
      TestStep(
        description: 'Enter username',
        action: () => AutomationEngine.instance
            .enterText(const Key('username_field'), 'tester'),
      ),
      TestStep(
        description: 'Enter password',
        action: () => AutomationEngine.instance
            .enterText(const Key('password_field'), 'secret'),
      ),
      TestStep(
        description: 'Submit',
        action: () => AutomationEngine.instance.tap(const Key('login_button')),
      ),
      TestStep(
        description: 'Dashboard is shown',
        action: () => Expect.visible(find.byText('Dashboard')),
      ),
    ],
  );
}
```

---

## 4. Make widgets addressable — your screen files

For every widget a test targets, give it a **stable `Key`** (preferred) or make
it findable by exact text / icon / tooltip.

```dart
TextField(
  key: const Key('username_field'), // add this
  decoration: const InputDecoration(labelText: 'Username'),
),

ElevatedButton(
  key: const Key('login_button'), // add this
  onPressed: _submit,
  child: const Text('Login'),
),
```

Key-naming convention: `snake_case`, describing the element
(`username_field`, `login_button`, `item_42_tile`). Keep them stable — they are
your test contract.

Finder options available: `find.byKey`, `find.byText` (exact),
`find.textContaining` (substring/RegExp), `find.byIcon`, `find.byType`,
`find.byWidget<T>()` (subtype), `find.byTooltip`, `find.descendant(...)`, plus
`.first` / `.last` / `.at(n)`.

**Requirements for reliable targeting:**
- Text fields must be real `TextField` / `TextFormField` (they contain an
  `EditableText`).
- Anything you scroll to must live inside a `Scrollable` (`ListView`,
  `SingleChildScrollView`, etc.); prefer giving the target a `Key`.
- Do not target widgets that are intentionally covered/disabled and expect a
  tap to "work" — it will raise `NotActionableException`.

---

## 5. Assertions & waiting (use these in steps)

```dart
await Expect.visible(target);        // present AND actually visible
await Expect.hidden(target);         // gone or not visible
await Expect.absent(target);         // not in the tree
await Expect.count(find.byText('Item'), 10);
await Expect.enabled(target);
await Expect.disabled(target);
await Expect.text(const Key('title'), 'Welcome');  // descends into children
await Expect.textContaining(target, 'Wel');
await AutomationEngine.instance.waitFor(target);   // wait until present
```

All assertions auto-retry until they hold or time out — do **not** add manual
`Future.delayed` sleeps.

---

## 6. Headless / CI entrypoint — `integration_test/automation_test.dart`

Create this file so the suite runs headlessly with a real exit code and writes
report artifacts.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:in_app_automation/in_app_automation.dart';
import 'package:in_app_automation/io.dart'; // TestArtifactWriter (dart:io)

import 'package:<your_app>/main.dart' as app; // your root widget
import 'package:<your_app>/automation/app_tests.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('automation suite (headless)', (tester) async {
    registerAutomationTests();
    await tester.pumpWidget(const app.MyApp()); // or your root widget
    await tester.pumpAndSettle();

    late final List<TestResult> results;
    await tester.runAsync(() async {
      final runner = TestRunner(
        config: TestRunConfig(
          defaultTimeout: const Duration(seconds: 20),
          screenshotOnFailure: () => AutomationScreenshot.capture(),
        ),
        listeners: [TestReporter.instance],
      );
      results = await runner.run(
        AutomationRegistry.instance.tests,
        hooks: AutomationRegistry.instance.hooks,
      );
      await TestArtifactWriter.write(results); // build/automation-reports/
    });

    expect(allPassed(results), isTrue,
        reason: 'See build/automation-reports/report.html');
  });
}
```

Run it on a device/emulator:

```bash
flutter test integration_test          # exits non-zero if any test fails
```

Artifacts land in `build/automation-reports/`: `report.json`, `junit.xml`,
`report.html` (failure screenshots embedded), and a `*.png` per failed test.

---

## 7. CI workflow — `.github/workflows/automation.yml`

```yaml
name: automation
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.3'
          channel: stable
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          arch: x86_64
          script: flutter test integration_test
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: automation-reports
          path: build/automation-reports/
          if-no-files-found: ignore
```

---

## 8. Release safety — nothing to enable for debug/CI

- In **debug / profile** builds automation is enabled automatically.
- In **release** builds it is **off by default** and `tap`/`enterText`/
  `scrollUntilVisible` throw `AutomationDisabledException`. Only if you
  deliberately automate a release build, call once at startup:

```dart
AutomationConfig.enable();
```

- Never register real credentials outside `if (kDebugMode)` (step 2).

---

## 9. Ignore generated artifacts — `.gitignore`

```gitignore
# Automation reports
build/automation-reports/
```

(Usually already covered by an existing `build/` rule.)

---

## Conventions

- **Isolation:** reset app state in `registry.beforeEach(...)`; don't let tests
  depend on each other's leftover state.
- **Tags:** tag suites (`{'smoke'}`, `{'checkout'}`) and filter in CI via
  `TestRunConfig(includeTags: {'smoke'})` or `grep`.
- **No sleeps:** rely on auto-waiting/actionability, not `Future.delayed`.
- **Stable keys:** treat `Key` names as an API contract.
- **Programmatic run (in-app):** `await AutomationController.instance.runAllTests();`
  then read `TestReporter.instance.detailedResults`.

---

## Troubleshooting

| Error | Meaning | Fix in the project |
|-------|---------|--------------------|
| `ElementNotFoundException` | finder matched nothing in time | add/verify the `Key` or text; ensure the screen is reached first |
| `NotActionableException` (disabled) | target has no active callback | the control is disabled — drive the flow so it becomes enabled |
| `NotActionableException` (obscured) | another widget covers the target | remove the overlay/barrier, or target what's actually on top |
| `NotVisibleException` | present but off-screen/clipped/`Offstage`/`Opacity 0` | scroll it into view or make it visible before asserting |
| `AutomationDisabledException` | running in a release build | use a debug/profile build, or call `AutomationConfig.enable()` |
| `No <axis> Scrollable found` | target isn't inside a scrollable | wrap the content in a `ListView`/scroll view, or pass the right `axis` |

---

## Completion checklist

- [ ] `in_app_automation` (and `integration_test`) added to `pubspec.yaml`; `pub get` run
- [ ] root widget wrapped in `AutomationInspectorWrapper`
- [ ] `registerAutomationTests()` called inside `if (kDebugMode)` before `runApp`
- [ ] `lib/automation/app_tests.dart` created with scenarios (+ `beforeEach` reset)
- [ ] `Key`s added to every targeted widget
- [ ] `integration_test/automation_test.dart` created
- [ ] CI workflow added
- [ ] `build/automation-reports/` git-ignored
- [ ] release-mode expectations understood (`AutomationConfig.enable()` only if needed)
- [ ] `flutter analyze` clean; `flutter test integration_test` green on a device

---

**Next:** with the project wired up, see the
[user-flow cookbook](USER_FLOWS.md) for copy-paste patterns (auth, navigation,
forms, lists, CRUD, dialogs, end-to-end). API reference: the [README](../README.md).
