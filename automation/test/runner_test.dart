import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart';

TestStep _step(String description, FutureOr<void> Function() action) =>
    TestStep(description: description, action: action);

TestCase _case(String name, List<TestStep> steps,
        {Set<String> tags = const {}, Duration? timeout, int? retries}) =>
    TestCase(name: name, steps: steps, tags: tags, timeout: timeout, retries: retries);

void main() {
  test('hooks run in the correct order around each test', () async {
    final log = <String>[];
    final tests = [
      _case('t1', [_step('s', () => log.add('t1.step'))]),
      _case('t2', [_step('s', () => log.add('t2.step'))]),
    ];
    final hooks = TestHooks(
      beforeAll: [() => log.add('beforeAll')],
      afterAll: [() => log.add('afterAll')],
      beforeEach: [() => log.add('beforeEach')],
      afterEach: [() => log.add('afterEach')],
    );

    final results = await TestRunner().run(tests, hooks: hooks);

    expect(allPassed(results), isTrue);
    expect(log, [
      'beforeAll',
      'beforeEach', 't1.step', 'afterEach',
      'beforeEach', 't2.step', 'afterEach',
      'afterAll',
    ]);
  });

  test('a flaky test passes on retry and is marked flaky', () async {
    var attempts = 0;
    final tests = [
      _case('flaky', [
        _step('maybe', () {
          attempts++;
          if (attempts < 2) throw StateError('boom');
        })
      ], retries: 2),
    ];

    final results = await TestRunner().run(tests);

    expect(results.single.passed, isTrue);
    expect(results.single.attempts, 2);
    expect(results.single.flaky, isTrue);
  });

  test('a test that always fails is reported failed after exhausting retries', () async {
    final tests = [
      _case('bad', [_step('nope', () => throw StateError('x'))], retries: 1),
    ];

    final results = await TestRunner().run(tests);

    expect(results.single.passed, isFalse);
    expect(results.single.outcome, TestOutcome.failed);
    expect(results.single.attempts, 2);
    expect(results.single.failedStep?.description, 'nope');
  });

  test('a step that exceeds the timeout is reported timedOut', () async {
    final tests = [
      _case('slow', [_step('sleep', () => Future.delayed(const Duration(seconds: 1)))],
          timeout: const Duration(milliseconds: 100)),
    ];

    final results = await TestRunner().run(tests);

    expect(results.single.outcome, TestOutcome.timedOut);
  });

  test('tag and grep filtering select the right tests', () async {
    final tests = [
      _case('login smoke', [_step('s', () {})], tags: {'smoke'}),
      _case('checkout slow', [_step('s', () {})], tags: {'slow'}),
    ];

    final smoke = await TestRunner(config: const TestRunConfig(includeTags: {'smoke'})).run(tests);
    expect(smoke.map((r) => r.test.name), ['login smoke']);

    final grep = await TestRunner(config: const TestRunConfig(grep: 'checkout')).run(tests);
    expect(grep.map((r) => r.test.name), ['checkout slow']);

    final excluded = await TestRunner(config: const TestRunConfig(excludeTags: {'slow'})).run(tests);
    expect(excluded.map((r) => r.test.name), ['login smoke']);
  });

  test('afterEach runs even when the test fails', () async {
    final log = <String>[];
    final tests = [
      _case('boom', [_step('explode', () => throw StateError('x'))]),
    ];
    final hooks = TestHooks(afterEach: [() => log.add('cleanup')]);

    await TestRunner().run(tests, hooks: hooks);

    expect(log, ['cleanup']);
  });
}
