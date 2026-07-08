# Automation 🚀

`automation` is an in-app UI testing tool for Flutter. You register tests in
Dart, then run them either from an on-device inspector overlay or headlessly in
CI. Actions drive **real input** — synthetic pointer and IME events routed
through Flutter's gesture and text pipelines — so a green result means a user
could actually perform the action.

---

## Table of Contents

- [What it does](#what-it-does)
- [Installation](#installation)
- [Setup](#setup)
- [Writing your first test](#writing-your-first-test)
- [Finders](#finders)
- [Actions](#actions)
- [Assertions](#assertions)
- [The test runner](#the-test-runner)
- [Reports and screenshots](#reports-and-screenshots)
- [Running headless in CI](#running-headless-in-ci)
- [Safety: release builds](#safety-release-builds)
- [Stability](#stability)

---

## What it does

- **Real input** — `tap` dispatches hit-tested pointer events through
  `GestureBinding`; `enterText` drives the field's real IME pipeline
  (`inputFormatters`, `onChanged`, selection, `onSubmitted`). Callbacks are not
  invoked directly, so covered / `IgnorePointer` / disabled widgets are
  correctly reported as not actionable instead of silently "passing".
- **Actionability + auto-waiting** — before acting, the target must exist,
  resolve to an enabled element, be visible (honoring `Offstage`, zero
  `Opacity`, and clips), and actually receive events at its center. These are
  re-checked until a timeout.
- **On-device inspector** — a floating overlay (debug builds) to pick and run
  tests and watch step-by-step progress.
- **Headless runner** — the same runner, wired to a process exit code for CI.

---

## Installation

Add it to your app's `pubspec.yaml`:

```yaml
dependencies:
  automation:
    path: path/to/automation
```

Then `flutter pub get`.

---

## Setup

Wrap your app with `AutomationInspectorWrapper`:

```dart
import 'package:automation/automation.dart';

void main() {
  runApp(AutomationInspectorWrapper(child: const MyApp()));
}
```

The overlay only renders in debug builds. In release, automation is disabled by
default (see [Safety](#safety-release-builds)).

---

## Writing your first test

Register tests before `runApp` (guard with `kDebugMode` so test code and any
credentials do not ship in release):

```dart
void main() {
  if (kDebugMode) {
    AutomationRegistry.instance.registerTest(
      name: 'Login',
      tags: {'smoke'},
      steps: [
        TestStep(
          description: 'Enter username',
          action: () => AutomationEngine.instance.enterText(const Key('username'), 'tester'),
        ),
        TestStep(
          description: 'Tap login',
          action: () => AutomationEngine.instance.tap(find.byText('LOGIN')),
        ),
        TestStep(
          description: 'Land on the dashboard',
          action: () => Expect.visible(find.byText('Inventory')),
        ),
      ],
    );
  }
  runApp(AutomationInspectorWrapper(child: const MyApp()));
}
```

---

## Finders

Via the global `find`:

| Finder | Matches |
|--------|---------|
| `find.byKey(key)` | widget by `Key` |
| `find.byText('x')` | `Text`/`EditableText` with exactly that text |
| `find.textContaining('x')` | substring; also accepts a `RegExp` |
| `find.byIcon(Icons.add)` | `Icon` |
| `find.byType(ElevatedButton)` | exact runtime type |
| `find.byWidget<ButtonStyleButton>()` | type **or subtype** |
| `find.byTooltip('Delete')` | `Tooltip` by message |
| `find.descendant(of:, matching:)` | child within a parent |

Narrow any finder with `.first`, `.last`, or `.at(n)`.

Actions and assertions also accept a `Key`, `String`, `IconData`, or `Type`
directly and resolve it to a finder.

---

## Actions

```dart
final engine = AutomationEngine.instance;
await engine.tap(target);                       // real hit-tested tap
await engine.enterText(target, 'hi', submit: true); // real IME input + submit
await engine.scrollUntilVisible(target, axis: Axis.vertical); // animated scroll
await engine.waitFor(target);                   // wait until present
await engine.pumpAndSettle();                   // wait until frames settle
```

`scrollUntilVisible` prefers the scrollable that contains the target (so nested
and horizontal lists work) and scrolls with real physics.

---

## Assertions

`Expect` assertions auto-retry until they hold or time out:

```dart
await Expect.visible(target);
await Expect.hidden(target);
await Expect.absent(target);
await Expect.count(find.byText('Item'), 10);
await Expect.enabled(target);
await Expect.disabled(target);
await Expect.text(const Key('title'), 'Welcome');   // descends into children
await Expect.textContaining(target, 'Wel');
```

Collect several without stopping at the first failure:

```dart
final soft = SoftAssertions();
await soft.check(() => Expect.visible(a));
await soft.check(() => Expect.text(b, 'x'));
soft.assertAll(); // throws once with every failure
```

Failures throw typed errors (`ElementNotFoundException`, `NotVisibleException`,
`NotActionableException`, `AutomationTimeoutException`,
`AutomationAssertionException`, …) — all subtypes of `AutomationException`.

---

## The test runner

`TestRunner` is the single execution core used by both the inspector and CI:

```dart
final results = await TestRunner(
  config: const TestRunConfig(
    defaultTimeout: Duration(seconds: 20),
    retries: 1,                 // retry failures; passing on retry marks flaky
    includeTags: {'smoke'},     // or excludeTags / grep by name
  ),
  listeners: [TestReporter.instance],
).run(
  AutomationRegistry.instance.tests,
  hooks: AutomationRegistry.instance.hooks,
);
```

Register setup/teardown (use `beforeEach` to reset app state for isolation):

```dart
AutomationRegistry.instance
  ..beforeAll(() { /* once before the run */ })
  ..beforeEach(() { /* reset app state before each test */ })
  ..afterEach(() { /* cleanup */ })
  ..afterAll(() { /* once after the run */ });
```

Each result carries its outcome, attempts, per-step timings, and error/stack.

---

## Reports and screenshots

When a test fails, a screenshot is captured automatically (before teardown)
and attached to its result — `AutomationController.runAllTests` and the
inspector both enable this by default. The HTML report embeds each failure's
screenshot inline.

Format results yourself with `TestReportFormatter`:

```dart
TestReportFormatter.toJson(results);     // structured JSON
TestReportFormatter.toJUnitXml(results); // JUnit XML for CI
TestReportFormatter.toHtml(results);     // HTML with embedded failure screenshots
```

Or write the whole set to disk (reports + a PNG per failed test) via the
IO entrypoint:

```dart
import 'package:automation/io.dart';

await AutomationController.instance.runAllTests();
await TestArtifactWriter.write(TestReporter.instance.detailedResults);
// -> build/automation-reports/{report.json, junit.xml, report.html, *.png}
```

Capture a screenshot manually at any time:

```dart
final png = await AutomationScreenshot.capture();
```

---

## Running headless in CI

Automation runs headlessly through `package:integration_test`, whose pass/fail
becomes the process exit code. See
[`example/integration_test/automation_test.dart`](example/integration_test/automation_test.dart)
for a complete entrypoint that runs the suite and writes JSON/JUnit/HTML
artifacts, and [`.github/workflows/automation-ci.yml`](../.github/workflows/automation-ci.yml)
for a reference workflow (analyze + unit/widget tests, plus the integration
suite on an emulator with artifact upload).

```bash
flutter test integration_test    # exits non-zero if any test fails
```

---

## Safety: release builds

Automation actuates the live app, so it is **enabled outside release builds
only** (debug and profile). In release, `tap`/`enterText`/`scrollUntilVisible`
throw `AutomationDisabledException` and `runAllTests` no-ops. Opt in
deliberately for release automation:

```dart
AutomationConfig.enable();   // allow automation in any build mode
```

---

## Stability

Pre-1.0 (`0.x`): the API may change between minor versions. Breaking changes are
called out in the [CHANGELOG](CHANGELOG.md). Once the interaction and runner
APIs settle, this will move to 1.0 with semver guarantees.

---

*Happy testing!* 🎉
