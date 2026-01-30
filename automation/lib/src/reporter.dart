import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'test_registry.dart';

/// Collects and manages test results.
class TestReporter {
  static final TestReporter instance = TestReporter._();
  TestReporter._();

  final List<TestRunResult> _results = [];
  List<TestRunResult> get results => List.unmodifiable(_results);
  
  /// Logs a message to the console (and eventually to a file).
  void log(String message) {
    if (kDebugMode) {
      print('[Automation] $message');
    }
  }

  void onTestStart(TestCase test) {
    log('Starting test: ${test.name}');
  }

  void onTestStepPassed(TestCase test, TestStep step, Duration duration) {
    log('✅ Step passed: ${step.description} (${duration.inMilliseconds}ms)');
  }

  void onTestStepFailed(TestCase test, TestStep step, Object error, StackTrace stack) {
    log('❌ Step failed: ${step.description}');
    log('Error: $error');
  }

  void onTestComplete(TestCase test, bool success, Duration duration) {
     log('Test ${success ? "PASSED" : "FAILED"}: ${test.name} (${duration.inMilliseconds}ms)');
     _results.add(TestRunResult(
       testName: test.name,
       success: success,
       durationMs: duration.inMilliseconds,
       timestamp: DateTime.now().toIso8601String(),
     ));
  }

  /// Exports results as a JSON string.
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
