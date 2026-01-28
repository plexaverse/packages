import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart';

void main() {
  test('Registering a test adds it to the registry', () {
    final registry = AutomationRegistry.instance;
    final initialLength = registry.tests.length;

    registry.registerTest(
      name: 'Test 1',
      steps: [
        TestStep(description: 'Step 1', action: () {}),
      ],
    );

    expect(registry.tests.length, initialLength + 1);
    expect(registry.tests.last.name, 'Test 1');
  });
}
