# Automation 🚀

Welcome to `automation`, a friendly and powerful tool to test your Flutter apps interactively!

If you are new to testing or Flutter, don't worry. This guide will walk you through everything step-by-step. By the end, you'll be able to watch your app run tests on its own, like magic! ✨

---

## 📚 Table of Contents

- [What does this package do?](#what-does-this-package-do)
- [Installation](#installation)
- [Setup](#setup)
- [Writing Your First Test](#writing-your-first-test)
- [Running Tests](#running-tests)
- [Smart Features](#smart-features)
- [For Advanced Users](#for-advanced-users)

---

## What does this package do?

Imagine you have a robot finger that can tap buttons and type text on your phone. This package gives you that robot finger! 🤖

- **It runs inside your app**: You don't need complicated computer setups or external drivers.
- **Visual Feedback**: You'll see ripples and highlights where the "robot" touches.
- **Interactive UI**: A floating green wand icon lets you pick and run tests directly on-device.
- **Programmatic runner**: Tests can be launched from Dart via `AutomationController`, not only from the on-device UI. (Note: this runs *inside* your app; it is not yet a standalone headless CI runner — see below.)

---

## Installation

1.  Open your `pubspec.yaml`.
2.  Add `automation` under `dependencies`:

```yaml
dependencies:
  automation:
    path: path/to/automation
```

3.  Run `flutter pub get`.

---

## Setup

Wrap your `MaterialApp` with `AutomationInspectorWrapper`:

```dart
import 'package:automation/automation.dart';

void main() {
  runApp(
    AutomationInspectorWrapper(
      child: MyApp(),
    ),
  );
}
```

---

## Writing Your First Test

### 1. Add Keys to your Widgets
Use `Key` to identify widgets you want to test.

```dart
TextField(
  key: const Key('username_field'),
  decoration: InputDecoration(labelText: 'Username'),
)
```

### 2. Register the Test
Register your tests **before** calling `runApp()`.

```dart
void main() {
  AutomationRegistry.instance.registerTest(
    name: 'Login Test',
    steps: [
      TestStep(
        description: 'Enter username',
        action: () async {
          await AutomationEngine.instance.enterText(const Key('username_field'), 'tester');
        },
      ),
      TestStep(
        description: 'Tap login',
        action: () async {
          await AutomationEngine.instance.tap(find.byText('LOGIN'));
        },
      ),
    ],
  );

  runApp(const MyApp());
}
```

---

## Smart Features

### 🕒 Dynamic Waiting
The package doesn't use static "sleep" times. The `waitFor` mechanism (used internally by `tap` and `enterText`) polls the widget tree every 200ms and proceeds **immediately** when the widget appears. This makes tests fast and reliable.

### 📜 Smart Scrolling
Use `scrollUntilVisible()` to find widgets hidden in long lists.
```dart
await AutomationEngine.instance.scrollUntilVisible(find.byText('Item 42'));
```
It automatically finds the largest vertical scrollable area and scrolls incrementally until the target is found and visible.

### 🔍 Powerful Finders
- `find.byKey(Key)`
- `find.byText(String)`
- `find.byIcon(IconData)`
- `find.byType(Type)`
- `find.descendant(of: ..., matching: ...)`

---

## For Advanced Users

### Assertions (Expect)
Verify UI state during tests:
- `Expect.visible(target)`: Waits until the widget is present and on-screen; fails if it stays missing, off-screen, or clipped by a scroll viewport. (Opacity 0, `Offstage`, and being covered by another widget are not yet detected.)
- `Expect.absent(target)`: Fails if widget is visible.
- `Expect.text(target, 'val')`: Fails if text doesn't match exactly.

### Programmatic Execution
Run all registered tests from code:
```dart
final passed = await AutomationController.instance.runAllTests();
```
`runAllTests()` returns whether every test passed. Note: this executes **inside your running app**, not as a standalone headless process — there is no built-in CLI or CI exit-code integration yet. To gate CI on the result today you must wire `passed` into your own harness (e.g. `integration_test` + `flutter test`). First-class headless/CI support is on the roadmap.

### Configuration
You can adjust the delay between steps in `inspector_ui.dart` (standard is ~250ms - 2500ms depending on your preference for watching the UI).

---

*Happy Testing!* 🎉
