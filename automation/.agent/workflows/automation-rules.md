---
description: Project rules and architecture guidelines for the automation package
---

# Automation Package - Project Rules & Architecture.

## 📁 Project Structure

```
automation/
├── lib/
│   ├── automation.dart          # Main export file + AutomationInspectorWrapper
│   └── src/
│       ├── controller.dart       # AutomationController (CI/CD headless mode)
│       ├── expect.dart           # Expect assertions (visible/absent/text)
│       ├── finders.dart          # AutomationFinder implementations
│       ├── inspector_ui.dart     # AutomationInspectorOverlay (visual UI)
│       ├── interaction_engine.dart # AutomationEngine (core interactions)
│       ├── reporter.dart         # TestReporter (results collection)
│       └── test_registry.dart    # TestCase, TestStep, AutomationRegistry
├── example/                      # Demo app showcasing package usage
└── test/                         # Unit tests
```

---

## 🏗️ Architecture

### Core Components

| Component | Class | Purpose |
|-----------|-------|---------|
| **Wrapper** | `AutomationInspectorWrapper` | Wraps MaterialApp to inject overlay (debug mode only) |
| **Registry** | `AutomationRegistry` | Singleton to register test cases |
| **Engine** | `AutomationEngine` | Core interaction methods (tap, enterText, scroll, waitFor) |
| **Inspector** | `AutomationInspectorOverlay` | Visual UI with floating button and test runner |
| **Controller** | `AutomationController` | Headless/CI mode test execution |
| **Reporter** | `TestReporter` | Collects and exports test results as JSON |
| **Expect** | `Expect` | Assertion utilities for UI verification |
| **Finders** | `AutomationFinder` | Widget locator strategies |

---

## 🔍 Widget Finders

Available finder strategies via the global `find` object:

| Finder | Usage | Example |
|--------|-------|---------|
| `byKey` | Find by widget Key | `find.byKey(const Key('login_btn'))` |
| `byText` | Find Text/RichText widget | `find.byText('Login')` |
| `byIcon` | Find Icon widget | `find.byIcon(Icons.add)` |
| `byType` | Find by widget type | `find.byType(ElevatedButton)` |
| `descendant` | Find child within parent | `find.descendant(of: parent, matching: child)` |

### Smart Target Resolution
Actions accept multiple target types that auto-resolve:
- `Key` → `KeyFinder`
- `String` → `TextFinder`
- `IconData` → `IconFinder`
- `Type` → `TypeFinder`
- `AutomationFinder` → Used directly

---

## ⚙️ Interaction Methods

### AutomationEngine Methods

```dart
// Core Actions
await AutomationEngine.instance.tap(target);           // Tap a widget
await AutomationEngine.instance.enterText(target, 'text'); // Type into field
await AutomationEngine.instance.scrollUntilVisible(target); // Scroll to find

// Waiting
await AutomationEngine.instance.waitFor(target);       // Dynamic wait (polls every 200ms)
await AutomationEngine.instance.pumpAndSettle();       // Wait for animations
```

### Timing Behavior

| Method | Behavior |
|--------|----------|
| `waitFor` | **Dynamic** - Polls every 200ms, returns immediately when found |
| `tap` / `enterText` | Uses `waitFor` internally before action |
| `scrollUntilVisible` | Scrolls incrementally until widget is visible |
| Step delay | Configurable delay between steps (default: 2500ms in inspector) |

---

## ✅ Assertions (Expect)

```dart
await Expect.visible(target);          // Assert widget is visible
await Expect.absent(target);           // Assert widget is NOT visible
await Expect.text(target, 'expected'); // Assert widget has exact text
```

---

## 📝 Test Registration Rules

1. **Register before runApp**: Always register tests before calling `runApp()`
2. **Use separate file**: Keep tests in `app_tests.dart` or similar
3. **Descriptive names**: Use clear step descriptions for debugging

```dart
void main() {
  registerAppTests();  // ← Register first
  runApp(const MyApp());
}

void registerAppTests() {
  AutomationRegistry.instance.registerTest(
    name: 'Test Name',
    steps: [
      TestStep(
        description: 'Step description',
        action: () async {
          // ... actions
        },
      ),
    ],
  );
}
```

---

## 🎨 UI Inspector Rules

1. **Floating button**: Positioned in bottom 40% of screen, snaps to edges
2. **Test status panel**: Shows running test with live step progress
3. **Minimizable**: Panel can be collapsed during test execution
4. **Highlight ripple**: Visual indicator shows where interactions occur

---

## 🚀 CI/CD Headless Mode

```dart
final passed = await AutomationController.instance.runAllTests(
  delayBetweenTests: Duration(seconds: 1),
);
// Returns true if all tests passed
```

---

## 🔧 Key Implementation Details

### Visibility Check (`_isVisible`)
- Verifies RenderBox is attached and has size
- Checks widget rect overlaps screen bounds
- Walks up tree to check viewport clipping

### Tap Resolution
1. Check if target element itself is tappable
2. Look UP for tappable ancestor with callback
3. Look DOWN for tappable descendant (legacy fallback)
4. Supported: `ButtonStyleButton`, `IconButton`, `InkWell`, `GestureDetector`, `ListTile`

### Scroll Strategy (`scrollUntilVisible`)
- Finds largest vertical scrollable in tree
- Jumps by `step` pixels (default 300)
- Max `maxScrolls` attempts (default 60)
- Uses `ensureVisible` once widget found in tree

---

## ⚠️ Important Rules

1. **Debug mode only**: Wrapper only shows in `kDebugMode`
2. **Keys are essential**: Add `Key` to widgets you want to interact with
3. **Dynamic waits**: Always use `waitFor` or action methods that wait internally
4. **Don't use static delays**: Rely on dynamic polling for reliability
5. **Step delay**: Configure inter-step delay in `inspector_ui.dart` line 494