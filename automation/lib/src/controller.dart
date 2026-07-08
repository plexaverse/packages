import 'package:flutter/foundation.dart';
import 'test_registry.dart';
import 'reporter.dart';

/// Controls test execution programmatically (e.g., for CI/CD or Headless mode).
class AutomationController {
  static final AutomationController instance = AutomationController._();
  AutomationController._();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Runs all registered tests sequentially.
  /// 
  /// Returns [true] if all tests passed, [false] otherwise.
  Future<bool> runAllTests({Duration delayBetweenTests = const Duration(seconds: 1)}) async {
    if (_isRunning) {
      debugPrint('[Automation] Tests are already running.');
      return false;
    }
    
    _isRunning = true;
    bool allTestsPassed = true;
    
    final tests = AutomationRegistry.instance.tests;
    debugPrint('[Automation] Starting execution of ${tests.length} tests...');

    for (final test in tests) {
      final success = await _runSingleTest(test);
      if (!success) allTestsPassed = false;
      await Future.delayed(delayBetweenTests);
    }

    _isRunning = false;
    
    // Final Report
    debugPrint('[Automation] ===================================');
    debugPrint('[Automation] All Tests Completed.');
    debugPrint('[Automation] Passed: ${TestReporter.instance.results.where((r) => r.success).length}');
    debugPrint('[Automation] Failed: ${TestReporter.instance.results.where((r) => !r.success).length}');
    debugPrint('[Automation] Result: ${allTestsPassed ? "SUCCESS" : "FAILURE"}');
    debugPrint('[Automation] ===================================');
    
    return allTestsPassed;
  }

  Future<bool> _runSingleTest(TestCase test) async {
    TestReporter.instance.onTestStart(test);
    final stopwatch = Stopwatch()..start();
    
    // Reset steps
    for (var s in test.steps) {
      s.status = TestStatus.pending;
    }

    bool passed = true;
    for (final step in test.steps) {
      step.status = TestStatus.running;
      final stepWatch = Stopwatch()..start();
      try {
        await step.action();
        stepWatch.stop();
        step.status = TestStatus.passed;
        TestReporter.instance.onTestStepPassed(test, step, stepWatch.elapsed);
      } catch (e, stack) {
        stepWatch.stop();
        step.status = TestStatus.failed;
        TestReporter.instance.onTestStepFailed(test, step, e, stack);
        passed = false;
        break;
      }
    }
    
    stopwatch.stop();
    TestReporter.instance.onTestComplete(test, passed, stopwatch.elapsed);
    return passed;
  }
}
