import 'package:flutter/foundation.dart';

import 'reporter.dart';
import 'runner.dart';
import 'test_registry.dart';

/// Controls test execution programmatically (e.g. for CI/headless mode).
///
/// This is a thin front-end over [TestRunner]: it runs the registered tests
/// with the given configuration, streams progress to [TestReporter], and
/// returns whether everything passed.
class AutomationController {
  static final AutomationController instance = AutomationController._();
  AutomationController._();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Runs all registered tests sequentially and returns true iff all passed.
  Future<bool> runAllTests({
    Duration delayBetweenTests = const Duration(seconds: 1),
    Duration defaultTimeout = const Duration(seconds: 30),
    int retries = 0,
    Set<String> includeTags = const {},
    Set<String> excludeTags = const {},
    Pattern? grep,
  }) async {
    if (_isRunning) {
      debugPrint('[Automation] Tests are already running.');
      return false;
    }

    _isRunning = true;
    try {
      final runner = TestRunner(
        config: TestRunConfig(
          delayBetweenTests: delayBetweenTests,
          defaultTimeout: defaultTimeout,
          retries: retries,
          includeTags: includeTags,
          excludeTags: excludeTags,
          grep: grep,
        ),
        listeners: [_ReporterBridge(TestReporter.instance)],
      );

      final results = await runner.run(
        AutomationRegistry.instance.tests,
        hooks: AutomationRegistry.instance.hooks,
      );

      final passed = allPassed(results);
      final flaky = results.where((r) => r.flaky).length;
      debugPrint('[Automation] ===================================');
      debugPrint('[Automation] All Tests Completed.');
      debugPrint('[Automation] Passed: ${results.where((r) => r.passed).length}/${results.length}');
      if (flaky > 0) debugPrint('[Automation] Flaky (passed on retry): $flaky');
      debugPrint('[Automation] Result: ${passed ? "SUCCESS" : "FAILURE"}');
      debugPrint('[Automation] ===================================');
      return passed;
    } finally {
      _isRunning = false;
    }
  }
}

/// Bridges runner progress to the existing [TestReporter] callbacks.
class _ReporterBridge extends TestRunListener {
  final TestReporter reporter;
  _ReporterBridge(this.reporter);

  @override
  void onTestStart(TestCase test) => reporter.onTestStart(test);

  @override
  void onStepFinished(TestCase test, StepResult result) {
    if (result.passed) {
      reporter.onTestStepPassed(test, result.step, result.duration);
    } else {
      reporter.onTestStepFailed(
        test,
        result.step,
        result.error ?? 'unknown error',
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  @override
  void onTestFinished(TestResult result) =>
      reporter.onTestComplete(result.test, result.passed, result.duration);
}
