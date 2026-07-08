import 'dart:async';
import 'dart:typed_data';

import 'test_registry.dart';

/// Final outcome of a single test run.
enum TestOutcome { passed, failed, timedOut }

/// Result of one step within a test.
class StepResult {
  final TestStep step;
  final int index;
  final bool passed;
  final Duration duration;
  final Object? error;
  final StackTrace? stackTrace;

  const StepResult({
    required this.step,
    required this.index,
    required this.passed,
    required this.duration,
    this.error,
    this.stackTrace,
  });
}

/// Result of running one [TestCase], including how many attempts it took.
class TestResult {
  final TestCase test;
  final TestOutcome outcome;
  final Duration duration;
  final int attempts;
  final List<StepResult> steps;
  final TestStep? failedStep;
  final Object? error;
  final StackTrace? stackTrace;

  /// PNG bytes captured at the moment of failure, if a capturer was configured.
  final Uint8List? screenshot;

  const TestResult({
    required this.test,
    required this.outcome,
    required this.duration,
    required this.attempts,
    required this.steps,
    this.failedStep,
    this.error,
    this.stackTrace,
    this.screenshot,
  });

  bool get passed => outcome == TestOutcome.passed;

  /// Passed, but only after one or more retries.
  bool get flaky => passed && attempts > 1;
}

/// A hook callback (setup/teardown).
typedef TestHook = FutureOr<void> Function();

/// Setup/teardown callbacks applied around a run.
class TestHooks {
  final List<TestHook> beforeAll;
  final List<TestHook> afterAll;
  final List<TestHook> beforeEach;
  final List<TestHook> afterEach;

  const TestHooks({
    this.beforeAll = const [],
    this.afterAll = const [],
    this.beforeEach = const [],
    this.afterEach = const [],
  });

  static const TestHooks empty = TestHooks();
}

/// Observes run progress. The reporter and the on-device inspector both
/// implement this so a single runner drives console output and the UI.
abstract class TestRunListener {
  void onRunStart(List<TestCase> tests) {}
  void onTestStart(TestCase test) {}
  void onStepStart(TestCase test, TestStep step, int index) {}
  void onStepFinished(TestCase test, StepResult result) {}
  void onTestFinished(TestResult result) {}
  void onRunFinished(List<TestResult> results) {}
}

/// Configuration for a run: timeouts, retries, filtering, and pacing.
class TestRunConfig {
  /// Per-test timeout when the test does not specify its own.
  final Duration defaultTimeout;

  /// Automatic retries on failure when the test does not specify its own.
  final int retries;

  /// If non-empty, only run tests carrying at least one of these tags.
  final Set<String> includeTags;

  /// Skip tests carrying any of these tags.
  final Set<String> excludeTags;

  /// If set, only run tests whose name contains this pattern.
  final Pattern? grep;

  /// Pause inserted between steps (useful to watch a run on-device).
  final Duration stepDelay;

  /// Pause inserted between tests.
  final Duration delayBetweenTests;

  /// If set, called when a test fails/times out to capture a screenshot
  /// (PNG bytes), attached to the [TestResult]. Kept as a callback so the
  /// runner stays free of any Flutter/UI dependency.
  final Future<Uint8List?> Function()? screenshotOnFailure;

  const TestRunConfig({
    this.defaultTimeout = const Duration(seconds: 30),
    this.retries = 0,
    this.includeTags = const {},
    this.excludeTags = const {},
    this.grep,
    this.stepDelay = Duration.zero,
    this.delayBetweenTests = Duration.zero,
    this.screenshotOnFailure,
  });
}

/// The single execution core shared by the headless controller and the
/// on-device inspector. Handles selection, hooks, per-test timeout, and
/// retries, emitting progress to any number of [TestRunListener]s.
class TestRunner {
  final TestRunConfig config;
  final List<TestRunListener> listeners;

  TestRunner({this.config = const TestRunConfig(), List<TestRunListener>? listeners})
      : listeners = listeners ?? <TestRunListener>[];

  bool selects(TestCase test) {
    if (config.grep != null && !test.name.contains(config.grep!)) return false;
    if (config.includeTags.isNotEmpty && test.tags.intersection(config.includeTags).isEmpty) {
      return false;
    }
    if (config.excludeTags.isNotEmpty && test.tags.intersection(config.excludeTags).isNotEmpty) {
      return false;
    }
    return true;
  }

  void _emit(void Function(TestRunListener) fn) {
    for (final l in listeners) {
      fn(l);
    }
  }

  Future<void> _runHooks(List<TestHook> hooks) async {
    for (final h in hooks) {
      await h();
    }
  }

  /// Runs [tests] (after filtering) and returns their results.
  Future<List<TestResult>> run(List<TestCase> tests, {TestHooks hooks = TestHooks.empty}) async {
    final selected = tests.where(selects).toList();
    _emit((l) => l.onRunStart(selected));

    final results = <TestResult>[];
    try {
      await _runHooks(hooks.beforeAll);
      for (final test in selected) {
        _emit((l) => l.onTestStart(test));
        final result = await _runOne(test, hooks);
        results.add(result);
        _emit((l) => l.onTestFinished(result));
        if (config.delayBetweenTests > Duration.zero) {
          await Future.delayed(config.delayBetweenTests);
        }
      }
    } finally {
      await _runHooks(hooks.afterAll);
    }

    _emit((l) => l.onRunFinished(results));
    return results;
  }

  Future<TestResult> _runOne(TestCase test, TestHooks hooks) async {
    final maxRetries = test.retries ?? config.retries;
    final timeout = test.timeout ?? config.defaultTimeout;
    final total = Stopwatch()..start();
    TestResult? lastFailure;

    for (var attempt = 1; attempt <= maxRetries + 1; attempt++) {
      for (final s in test.steps) {
        s.status = TestStatus.pending;
      }
      final stepResults = <StepResult>[];
      TestStep? failedStep;
      Object? error;
      StackTrace? stack;
      var outcome = TestOutcome.passed;

      try {
        await _runHooks(hooks.beforeEach);
        await _runSteps(test, stepResults, (step, e, st) {
          failedStep = step;
          error = e;
          stack = st;
        }).timeout(timeout);
      } on TimeoutException catch (e, st) {
        outcome = TestOutcome.timedOut;
        error ??= e;
        stack ??= st;
      } catch (e, st) {
        outcome = TestOutcome.failed;
        error ??= e;
        stack ??= st;
      }

      // Capture a screenshot at the failure point, BEFORE teardown can change
      // the screen. Capture failures must not mask the test outcome.
      Uint8List? screenshot;
      if (outcome != TestOutcome.passed && config.screenshotOnFailure != null) {
        try {
          screenshot = await config.screenshotOnFailure!();
        } catch (_) {
          // Ignore capture failures.
        }
      }

      // afterEach always runs, even on failure or timeout.
      try {
        await _runHooks(hooks.afterEach);
      } catch (_) {
        // A teardown failure should not mask the test outcome.
      }

      if (outcome == TestOutcome.passed) {
        total.stop();
        return TestResult(
          test: test,
          outcome: TestOutcome.passed,
          duration: total.elapsed,
          attempts: attempt,
          steps: stepResults,
        );
      }

      lastFailure = TestResult(
        test: test,
        outcome: outcome,
        duration: total.elapsed,
        attempts: attempt,
        steps: stepResults,
        failedStep: failedStep,
        error: error,
        stackTrace: stack,
        screenshot: screenshot,
      );
    }

    total.stop();
    return lastFailure!;
  }

  Future<void> _runSteps(
    TestCase test,
    List<StepResult> stepResults,
    void Function(TestStep step, Object error, StackTrace stack) onStepError,
  ) async {
    for (var i = 0; i < test.steps.length; i++) {
      final step = test.steps[i];
      step.status = TestStatus.running;
      _emit((l) => l.onStepStart(test, step, i));
      final sw = Stopwatch()..start();
      try {
        await step.action();
        sw.stop();
        step.status = TestStatus.passed;
        final result = StepResult(step: step, index: i, passed: true, duration: sw.elapsed);
        stepResults.add(result);
        _emit((l) => l.onStepFinished(test, result));
      } catch (e, st) {
        sw.stop();
        step.status = TestStatus.failed;
        final result =
            StepResult(step: step, index: i, passed: false, duration: sw.elapsed, error: e, stackTrace: st);
        stepResults.add(result);
        _emit((l) => l.onStepFinished(test, result));
        onStepError(step, e, st);
        rethrow;
      }
      if (config.stepDelay > Duration.zero) {
        await Future.delayed(config.stepDelay);
      }
    }
  }
}

/// Whether every result in [results] passed.
bool allPassed(List<TestResult> results) => results.every((r) => r.passed);
