import 'package:flutter/material.dart';
import 'package:automation/automation.dart';

void registerAppTests() {
  
  AutomationRegistry.instance.registerTest(
    name: '1. Login Flow (Smart Finders)',
    steps: [
      TestStep(
        description: 'Verify Login Screen',
        action: () async {
          await Expect.visible(find.byText('Automation Login'));
          await Expect.visible(find.byKey(const Key('login_btn')));
        },
      ),
      TestStep(
        description: 'Enter Username',
        action: () async {
          await AutomationEngine.instance.enterText(const Key('username_input'), 'tester');
        },
      ),
      TestStep(
        description: 'Enter Password',
        action: () async {
          await AutomationEngine.instance.enterText(const Key('password_input'), 'password');
        },
      ),
      TestStep(
        description: 'Tap Login',
        action: () async {
          await AutomationEngine.instance.tap(find.byText('LOGIN'));
        },
      ),
      TestStep(
        description: 'Wait for Dashboard',
        action: () async {
          await AutomationEngine.instance.waitFor(find.byText('Inventory'));
        },
      ),
    ],
  );

  AutomationRegistry.instance.registerTest(
    name: '2. Scroll & View Details',
    steps: [
      TestStep(
        description: 'Ensure we are on List',
        action: () async {
          await Expect.visible(find.byText('Inventory'));
        },
      ),
      TestStep(
        description: 'Scroll to Item 42',
        action: () async {
          // New Feature: Scroll until we see the text
          await AutomationEngine.instance.scrollUntilVisible(find.byText('Item 42'));
        },
      ),
      TestStep(
        description: 'Tap Item 42',
        action: () async {
          await AutomationEngine.instance.tap(find.byText('Item 42'));
        },
      ),
      TestStep(
        description: 'Verify Details Screen',
        action: () async {
          await Expect.visible(find.byText('Item 42 Details'));
          await Expect.text(find.byText('Viewing details for #42'), 'Viewing details for #42');
        },
      ),
      TestStep(
        description: 'Go Back',
        action: () async {
          await AutomationEngine.instance.tap(find.byIcon(Icons.arrow_back));
        },
      ),
    ],
  );

  AutomationRegistry.instance.registerTest(
    name: '3. Headless Mode Check',
    steps: [
      TestStep(
        description: 'Print Console Log',
        action: () async {
          // This test just proves we can run arbitrary code
          debugPrint("Headless mode is working if you see this!");
        },
      ),
    ],
  );
}
