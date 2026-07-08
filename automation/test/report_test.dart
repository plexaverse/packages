import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart';

TestStep _step(String d) => TestStep(description: d, action: () {});

List<TestResult> _sample() {
  final passStep = _step('do a thing');
  final failStep = _step('do the bad thing');
  return [
    TestResult(
      test: TestCase(name: 'A passes', steps: [passStep], tags: {'smoke'}),
      outcome: TestOutcome.passed,
      duration: const Duration(milliseconds: 120),
      attempts: 1,
      steps: [StepResult(step: passStep, index: 0, passed: true, duration: const Duration(milliseconds: 120))],
    ),
    TestResult(
      test: TestCase(name: 'B fails', steps: [failStep]),
      outcome: TestOutcome.failed,
      duration: const Duration(milliseconds: 80),
      attempts: 2,
      failedStep: failStep,
      error: 'boom & <crash>',
      screenshot: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 10, 20, 30]),
      steps: [
        StepResult(
          step: failStep,
          index: 0,
          passed: false,
          duration: const Duration(milliseconds: 80),
          error: 'boom & <crash>',
        ),
      ],
    ),
  ];
}

void main() {
  test('JSON report captures summary, steps, and errors', () {
    final json = jsonDecode(TestReportFormatter.toJson(_sample())) as Map<String, dynamic>;

    expect(json['summary']['total'], 2);
    expect(json['summary']['passed'], 1);
    expect(json['summary']['failed'], 1);

    final tests = json['tests'] as List;
    expect(tests[0]['name'], 'A passes');
    expect(tests[0]['tags'], ['smoke']);
    expect(tests[1]['failedStep'], 'do the bad thing');
    expect(tests[1]['error'], contains('boom'));
    expect((tests[1]['steps'] as List).first['passed'], isFalse);
  });

  test('JUnit XML reports counts, a failure element, and escapes text', () {
    final xml = TestReportFormatter.toJUnitXml(_sample());

    expect(xml, contains('tests="2"'));
    expect(xml, contains('failures="1"'));
    expect(xml, contains('<failure'));
    // The error contained & and <> which must be escaped, not raw.
    expect(xml, contains('&amp;'));
    expect(xml, isNot(contains('boom & <crash>')));
  });

  test('HTML report lists every test with a status', () {
    final html = TestReportFormatter.toHtml(_sample());
    expect(html, contains('<table'));
    expect(html, contains('A passes'));
    expect(html, contains('B fails'));
    expect(html, contains('1 / 2 passed'));
  });

  test('HTML embeds a base64 screenshot for a failure that has one', () {
    final html = TestReportFormatter.toHtml(_sample());
    expect(html, contains('data:image/png;base64,'));
  });

  test('JSON flags whether each test has a screenshot', () {
    final json = jsonDecode(TestReportFormatter.toJson(_sample())) as Map<String, dynamic>;
    final tests = json['tests'] as List;
    expect(tests[0]['hasScreenshot'], isFalse);
    expect(tests[1]['hasScreenshot'], isTrue);
  });
}
