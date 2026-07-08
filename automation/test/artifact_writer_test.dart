import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart';
import 'package:automation/io.dart';

void main() {
  test('writes JSON/JUnit/HTML reports and a PNG for a failed test', () async {
    final passStep = TestStep(description: 'ok', action: () {});
    final failStep = TestStep(description: 'boom', action: () {});
    final results = [
      TestResult(
        test: TestCase(name: 'A ok', steps: [passStep]),
        outcome: TestOutcome.passed,
        duration: const Duration(milliseconds: 5),
        attempts: 1,
        steps: [StepResult(step: passStep, index: 0, passed: true, duration: const Duration(milliseconds: 5))],
      ),
      TestResult(
        test: TestCase(name: 'B fails / weird name', steps: [failStep]),
        outcome: TestOutcome.failed,
        duration: const Duration(milliseconds: 5),
        attempts: 1,
        failedStep: failStep,
        error: 'x',
        screenshot: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2]),
        steps: [StepResult(step: failStep, index: 0, passed: false, duration: const Duration(milliseconds: 5), error: 'x')],
      ),
    ];

    final tmp = await Directory.systemTemp.createTemp('automation_report_test');
    addTearDown(() => tmp.delete(recursive: true));

    final path = await TestArtifactWriter.write(results, directory: tmp.path);

    expect(File('${tmp.path}/report.json').existsSync(), isTrue);
    expect(File('${tmp.path}/junit.xml').existsSync(), isTrue);
    expect(File('${tmp.path}/report.html').existsSync(), isTrue);

    final pngs = tmp.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();
    expect(pngs.length, 1, reason: 'exactly the one failed-with-screenshot test writes a PNG');
    expect(path, isNotEmpty);
  });
}
