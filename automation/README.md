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
- [For Advanced Users](#for-advanced-users)

---

## What does this package do?

Imagine you have a robot finger that can tap buttons and type text on your phone. This package gives you that robot finger! 🤖

- **It runs inside your app**: You don't need complicated computer setups.
- **It shows you what's happening**: You'll see ripples and highlights where the "robot" touches.
- **It has a cool menu**: A floating button lets you pick which test to run.

---

## Installation

First, we need to add this package to your project.

1.  Open your project folder.
2.  Find the file named `pubspec.yaml` (it's in the main folder).
3.  Add `automation` under `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Add this line:
  automation:
    path: ../automation  # (Or use the version from pub.dev if published)
```

4.  Save the file and run `flutter pub get` in your terminal to download it.

---

## Setup

Now, let's turn on the automation tool in your app.

1.  Open your `lib/main.dart` file.
2.  Import the package at the top:

```dart
import 'package:automation/automation.dart';
```

3.  Find your `MaterialApp`. You need to wrap it (or your main screen) with `AutomationInspectorWrapper`.

**Example:**

```dart
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Wrap your app in the AutomationInspectorWrapper
    return AutomationInspectorWrapper(
      child: MaterialApp(
        title: 'My App',
        home: const HomeScreen(),
      ),
    );
  }
}
```

That's it! When you run your app now, you should see a **green wand icon** floating at the bottom. 🪄

---

## Writing Your First Test

Let's tell the robot what to do. We call these "Tests".

A test is just a list of steps, like:
1.  "Wait for the login button."
2.  "Type 'hello' in the email box."
3.  "Tap 'Login'."

To find widgets (buttons, text fields), we give them a `Key`. A Key is like a nametag.

### Step 1: Add Keys to your Widgets

Go to the screen you want to test and add keys to the widgets you want to interact with.

```dart
// Adding a key to a Button
ElevatedButton(
  key: const Key('my_login_button'), // <--- The Nametag
  onPressed: () {},
  child: const Text('Login'),
)

// Adding a key to a TextField
TextField(
  key: const Key('email_input'),    // <--- The Nametag
  decoration: const InputDecoration(labelText: 'Email'),
)
```

### Step 2: Create the Test

In your `main()` function (or a separate file), tell the `AutomationRegistry` about your test.

```dart
void main() {
  // Register your test BEFORE runApp
  AutomationRegistry.instance.registerTest(
    name: 'My First Test',
    steps: [
      // Step 1: Tap the email field
      TestStep(
        description: 'Tap email field',
        action: () async {
          // You can use Keys...
          await AutomationEngine.instance.tap(const Key('email_input'));
        },
      ),
      
      // Step 2: Type some text
      TestStep(
        description: 'Type hello',
        action: () async {
          // ...or use the handy 'find' API!
          await AutomationEngine.instance.enterText(find.byKey(const Key('email_input')), 'hello@world.com');
        },
      ),
      
      // Step 3: Scroll comfortably to the button if needed
      TestStep(
        description: 'Scroll to Login',
        action: () async {
          await AutomationEngine.instance.scrollUntilVisible(find.byText('Login'));
        },
      ),

      // Step 4: Tap the button by text
      TestStep(
        description: 'Tap Login',
        action: () async {
          await AutomationEngine.instance.tap(find.byText('Login'));
        },
      ),
    ],
  );

  runApp(const MyApp());
}
```

---

## Running Tests

1.  Run your app on a Simulator or real phone (`flutter run`).
2.  Tap the **Green Wand Icon** 🪄 at the bottom of the screen.
3.  You will see a menu "Automation Test Cases".
4.  Tap the **Play Button** ▶️ next to "My First Test".
5.  Watch your app drive itself! 🚗💨

---

## For Advanced Users

### The API

The `AutomationEngine` has these helpful methods:

- `tap(Key key)`: Taps a widget.
- `enterText(Key key, String text)`: Types text into a field.
- `waitForWidget(Key key, {Duration timeout})`: Waits until a widget appears (useful for loading screens).
- `pumpAndSettle()`: Waits for animations to finish.

### Assertions

Verify your app state with `Expect`:

- `Expect.visible(finder)`: Fails if widget is not on screen.
- `Expect.text(finder, 'Hello')`: Fails if widget doesn't have that text.
- `Expect.absent(finder)`: Fails if widget IS on screen.

## 🚀 CI/CD & Headless Mode

To run tests automatically (e.g., in a CI pipeline), use the `AutomationController`:

```dart
void main() async {
  // ... Registration of tests ...
  
  runApp(const MyApp());
  
  // Trigger tests after a delay
  Future.delayed(const Duration(seconds: 2), () async {
    final passed = await AutomationController.instance.runAllTests();
    // Communicate result to CI/CD (e.g. exit(passed ? 0 : 1))
    // Note: 'exit' requires dart:io
  });
}
```

The controller prints results to the console in a readable format.

### Best Practices

- Keep your tests in a separate file (e.g., `app_tests.dart`) and call a function like `registerAppTests()` in `main()`.
- Use descriptive names for your Keys so you remember what they are.

---

*Happy Testing!* 🎉
