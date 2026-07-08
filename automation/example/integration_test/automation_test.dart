// Headless entrypoint: runs the automation suite on a real device/emulator so
// its pass/fail becomes the process exit code, and writes report artifacts for
// CI to upload.
//
// Run with:
//   flutter test integration_test
//
// `flutter test` exits non-zero if the final expect() fails, which is what
// gates CI. Report artifacts are written under build/automation-reports/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:automation/automation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('automation suite runs headlessly and writes report artifacts', (tester) async {
    // A small app under test. (A real project would pump its own root widget.)
    var handledTap = false;
    await tester.pumpWidget(
      AutomationInspectorWrapper(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('go'),
                onPressed: () => handledTap = true,
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Register the tests to run.
    AutomationRegistry.instance
      ..clear()
      ..registerTest(
        name: 'Tapping Go runs its handler',
        tags: {'smoke'},
        steps: [
          TestStep(
            description: 'Tap the Go button',
            action: () => AutomationEngine.instance.tap(const Key('go')),
          ),
          TestStep(
            description: 'The button handler ran',
            action: () async {
              if (!handledTap) throw StateError('the button handler did not run');
            },
          ),
        ],
      );

    late final List<TestResult> results;
    await tester.runAsync(() async {
      final runner = TestRunner(
        config: const TestRunConfig(defaultTimeout: Duration(seconds: 20)),
        listeners: [TestReporter.instance],
      );
      results = await runner.run(
        AutomationRegistry.instance.tests,
        hooks: AutomationRegistry.instance.hooks,
      );
    });

    // Persist artifacts for CI to collect.
    final dir = Directory('build/automation-reports')..createSync(recursive: true);
    File('${dir.path}/report.json').writeAsStringSync(TestReportFormatter.toJson(results));
    File('${dir.path}/junit.xml').writeAsStringSync(TestReportFormatter.toJUnitXml(results));
    File('${dir.path}/report.html').writeAsStringSync(TestReportFormatter.toHtml(results));

    // This gates CI: a non-zero exit if any automation test failed.
    expect(allPassed(results), isTrue,
        reason: 'One or more automation tests failed; see build/automation-reports/report.html');
  });
}
