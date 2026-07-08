import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'runner.dart';
import 'test_registry.dart';

/// Collects and logs test results. Implemented as a [TestRunListener] so a
/// single [TestRunner] drives both console reporting and (via other listeners)
/// the on-device inspector.
class TestReporter extends TestRunListener {
  static final TestReporter instance = TestReporter._();
  TestReporter._();

  final List<TestRunResult> _results = [];
  List<TestRunResult> get results => List.unmodifiable(_results);

  /// Clears the recorded run history.
  void clear() => _results.clear();

  void log(String message) {
    if (kDebugMode) {
      debugPrint('[Automation] $message');
    }
  }

  @override
  void onRunStart(List<TestCase> tests) => log('Running ${tests.length} test(s)...');

  @override
  void onTestStart(TestCase test) => log('Starting test: ${test.name}');

  @override
  void onStepFinished(TestCase test, StepResult result) {
    if (result.passed) {
      log('✅ Step passed: ${result.step.description} (${result.duration.inMilliseconds}ms)');
    } else {
      log('❌ Step failed: ${result.step.description}');
      log('   Error: ${result.error}');
    }
  }

  @override
  void onTestFinished(TestResult result) {
    final label = switch (result.outcome) {
      TestOutcome.passed => result.flaky ? 'PASSED (flaky)' : 'PASSED',
      TestOutcome.failed => 'FAILED',
      TestOutcome.timedOut => 'TIMED OUT',
    };
    log('Test $label: ${result.test.name} (${result.duration.inMilliseconds}ms)');
    _results.add(TestRunResult(
      testName: result.test.name,
      success: result.passed,
      durationMs: result.duration.inMilliseconds,
      timestamp: DateTime.now().toIso8601String(),
    ));
  }

  /// Exports the recorded results as a JSON string.
  String exportJson() {
    return jsonEncode(_results.map((r) => r.toJson()).toList());
  }
}

class TestRunResult {
  final String testName;
  final bool success;
  final int durationMs;
  final String timestamp;

  TestRunResult({
    required this.testName,
    required this.success,
    required this.durationMs,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'testName': testName,
        'success': success,
        'durationMs': durationMs,
        'timestamp': timestamp,
      };
}
