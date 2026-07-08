import 'dart:async';

import 'runner.dart';

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

  /// Tags for filtering (e.g. {'smoke', 'auth'}).
  final Set<String> tags;

  /// Per-test timeout; falls back to the runner's default when null.
  final Duration? timeout;

  /// Per-test retry count; falls back to the runner's default when null.
  final int? retries;

  TestCase({
    required this.name,
    required this.steps,
    this.tags = const {},
    this.timeout,
    this.retries,
  });
}

/// Singleton registry for tests and their setup/teardown hooks.
class AutomationRegistry {
  AutomationRegistry._();
  static final AutomationRegistry instance = AutomationRegistry._();

  final List<TestCase> _tests = [];
  final List<TestHook> _beforeAll = [];
  final List<TestHook> _afterAll = [];
  final List<TestHook> _beforeEach = [];
  final List<TestHook> _afterEach = [];

  List<TestCase> get tests => List.unmodifiable(_tests);

  void registerTest({
    required String name,
    required List<TestStep> steps,
    Set<String> tags = const {},
    Duration? timeout,
    int? retries,
  }) {
    _tests.add(TestCase(name: name, steps: steps, tags: tags, timeout: timeout, retries: retries));
  }

  /// Runs once before the first test in a run.
  void beforeAll(TestHook hook) => _beforeAll.add(hook);

  /// Runs once after the last test in a run.
  void afterAll(TestHook hook) => _afterAll.add(hook);

  /// Runs before every test (and every retry) - the place to reset app state
  /// so tests are isolated from one another.
  void beforeEach(TestHook hook) => _beforeEach.add(hook);

  /// Runs after every test (and every retry), even on failure.
  void afterEach(TestHook hook) => _afterEach.add(hook);

  /// The registered hooks, packaged for the runner.
  TestHooks get hooks => TestHooks(
        beforeAll: List.unmodifiable(_beforeAll),
        afterAll: List.unmodifiable(_afterAll),
        beforeEach: List.unmodifiable(_beforeEach),
        afterEach: List.unmodifiable(_afterEach),
      );

  /// Clears all registered tests and hooks. Mainly useful for testing the
  /// framework itself.
  void clear() {
    _tests.clear();
    _beforeAll.clear();
    _afterAll.clear();
    _beforeEach.clear();
    _afterEach.clear();
  }
}
