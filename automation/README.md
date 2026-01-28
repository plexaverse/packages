# Realtime Tester 🚀

A powerful, interactive, and real-time testing solution for Flutter. `automation` allows developers to run automated tests directly on a mobile device or emulator, providing visual feedback and highlighting as each step executes.

## Features

- 📱 **On-Device Execution**: Run tests directly within your app, no external drivers required for playback.
- ✨ **Visual Feedback**: Real-time highlighting (ripple effects) of widgets being interacted with.
- 🛠 **In-App Inspector**: A sleek, glassmorphic overlay to manage and trigger tests.
- 🤖 **Interaction Engine**: Programmatically simulate taps, text entry, and waits using widget `Keys`.
- 📊 **Step-by-Step Status**: Watch your tests progress with a live status indicator and progress bar.

## Getting Started

### Installation

Add `automation` to your `pubspec.yaml`:

```yaml
dependencies:
  automation:
    path: ../automation # Use your local path or git/pub version
```

Wait for `flutter pub get` to complete.

### Setup

Wrap your main application widget with `AutomationInspectorWrapper` (usually in the `builder` of your `MaterialApp` or at the root):

```dart
import 'package:automation/automation.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return AutomationInspectorWrapper(
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}
```

## Usage

### 1. Registering Tests

You can register tests anywhere in your app (typically in `main.dart` or a dedicated test setup file) using `AutomationRegistry`.

```dart
AutomationRegistry.instance.registerTest(
  name: 'Login Flow Test',
  steps: [
    TestStep(
      description: 'Wait for Login Button',
      action: () async {
        await AutomationEngine.instance.waitForWidget(const Key('login_btn'));
      },
    ),
    TestStep(
      description: 'Enter Username',
      action: () async {
        await AutomationEngine.instance.enterText(const Key('user_field'), 'test_user');
      },
    ),
    TestStep(
      description: 'Tap Login',
      action: () async {
        await AutomationEngine.instance.tap(const Key('login_btn'));
      },
    ),
  ],
);
```

### 2. Interaction Engine API

The `AutomationEngine` provides the following capabilities:

| Method | Description |
| --- | --- |
| `tap(Key key)` | Simulates a tap on the widget with the given key. |
| `enterText(Key key, String text)` | Enters text into a `TextField` or `TextFormField`. |
| `waitForWidget(Key key, {Duration timeout})` | Polls the widget tree until a widget with the key is found. |
| `findRenderBoxByKey(Key key)` | Low-level utility to find the `RenderBox` of a specific widget. |

### 3. Using the Inspector

1.  Launch your app on a device or emulator.
2.  Tap the floating **Bug/Green** button at the bottom-left corner.
3.  Select a test from the menu to start execution.
4.  Observe the red ripple effects highlighting each interaction.

## Example

For a complete working demonstration, check the [example](example/lib/main.dart) folder.

```bash
cd example
flutter run
```

---

*Built with ❤️ for Flutter Developers.*
