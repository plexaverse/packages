import 'dart:async';

/// Represents a single step in a test.
class TestStep {
  final String description;
  final FutureOr<void> Function() action;
  TestStatus status;

  TestStep({
    required this.description,
    required this.action,
    this.status = TestStatus.pending,
  });
}

enum TestStatus { pending, running, passed, failed }

/// A registered test case.
class TestCase {
  final String name;
  final List<TestStep> steps;

  TestCase({required this.name, required this.steps});
}

/// Singleton registry for real-time tests.
class AutomationRegistry {
  AutomationRegistry._();
  static final AutomationRegistry instance = AutomationRegistry._();

  final List<TestCase> _tests = [];
  List<TestCase> get tests => List.unmodifiable(_tests);

  void registerTest({required String name, required List<TestStep> steps}) {
    _tests.add(TestCase(name: name, steps: steps));
  }
}
