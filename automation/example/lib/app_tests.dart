import 'package:flutter/material.dart';
import 'package:automation/automation.dart';

void registerAppTests() {
  // Register a complex multi-page test
  AutomationRegistry.instance.registerTest(
    name: 'End-to-End Profile Test',
    steps: [
      TestStep(
        description: 'Check if we are on Home',
        action: () async {
          await AutomationEngine.instance.waitForWidget(const Key('start_form_btn'));
        },
      ),
      TestStep(
        description: 'Navigate to Form',
        action: () async {
          await AutomationEngine.instance.tap(const Key('start_form_btn'));
        },
      ),
      TestStep(
        description: 'Enter Name: Asang Borkar',
        action: () async {
          await AutomationEngine.instance.enterText(const Key('name_field'), 'Antigravity');
        },
      ),
      TestStep(
        description: 'Enter Email: asangborkarofficial@gmail.com',
        action: () async {
          await AutomationEngine.instance.enterText(const Key('email_field'), 'ai@google.com');
        },
      ),
      TestStep(
        description: 'Submit Profile',
        action: () async {
          await AutomationEngine.instance.tap(const Key('submit_btn'));
        },
      ),
      TestStep(
        description: 'Verify Success Screen',
        action: () async {
          await AutomationEngine.instance.waitForWidget(const Key('success_icon'));
        },
      ),
    ],
  );
}
