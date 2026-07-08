import 'dart:convert';

import 'runner.dart';

/// Formats [TestResult]s into report artifacts (JSON, JUnit XML, HTML).
///
/// Pure string generation - no `dart:io` - so it stays web-safe. A CI
/// entrypoint (which is not web) writes these strings to disk.
class TestReportFormatter {
  const TestReportFormatter._();

  /// A structured summary + per-test/per-step breakdown as a JSON-ready map.
  static Map<String, dynamic> toMap(List<TestResult> results) {
    return {
      'summary': {
        'total': results.length,
        'passed': results.where((r) => r.passed).length,
        'failed': results.where((r) => r.outcome == TestOutcome.failed).length,
        'timedOut': results.where((r) => r.outcome == TestOutcome.timedOut).length,
        'flaky': results.where((r) => r.flaky).length,
        'durationMs': results.fold<int>(0, (sum, r) => sum + r.duration.inMilliseconds),
      },
      'tests': [
        for (final r in results)
          {
            'name': r.test.name,
            'outcome': r.outcome.name,
            'passed': r.passed,
            'flaky': r.flaky,
            'attempts': r.attempts,
            'durationMs': r.duration.inMilliseconds,
            'tags': r.test.tags.toList(),
            if (r.failedStep != null) 'failedStep': r.failedStep!.description,
            if (r.error != null) 'error': r.error.toString(),
            'steps': [
              for (final s in r.steps)
                {
                  'index': s.index,
                  'description': s.step.description,
                  'passed': s.passed,
                  'durationMs': s.duration.inMilliseconds,
                  if (s.error != null) 'error': s.error.toString(),
                },
            ],
          },
      ],
    };
  }

  /// Pretty (or compact) JSON.
  static String toJson(List<TestResult> results, {bool pretty = true}) {
    final encoder = pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(toMap(results));
  }

  /// JUnit XML, consumable by most CI systems' test reporters.
  static String toJUnitXml(List<TestResult> results, {String suiteName = 'automation'}) {
    final failures = results.where((r) => !r.passed).length;
    final totalSeconds = results.fold<int>(0, (s, r) => s + r.duration.inMilliseconds) / 1000.0;

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<testsuites name="${_attr(suiteName)}" tests="${results.length}" '
          'failures="$failures" time="${totalSeconds.toStringAsFixed(3)}">')
      ..writeln('  <testsuite name="${_attr(suiteName)}" tests="${results.length}" failures="$failures">');

    for (final r in results) {
      final time = (r.duration.inMilliseconds / 1000.0).toStringAsFixed(3);
      buffer.write('    <testcase name="${_attr(r.test.name)}" time="$time"');
      if (r.passed) {
        buffer.writeln(' />');
      } else {
        final kind = r.outcome == TestOutcome.timedOut ? 'timeout' : 'failure';
        final where = r.failedStep != null ? 'step "${r.failedStep!.description}": ' : '';
        buffer
          ..writeln('>')
          ..writeln('      <failure type="$kind" message="${_attr('$where${r.error ?? r.outcome.name}')}">'
              '${_text(r.stackTrace?.toString() ?? r.error?.toString() ?? r.outcome.name)}</failure>')
          ..writeln('    </testcase>');
      }
    }

    buffer
      ..writeln('  </testsuite>')
      ..writeln('</testsuites>');
    return buffer.toString();
  }

  /// A minimal self-contained HTML report.
  static String toHtml(List<TestResult> results, {String title = 'Automation Report'}) {
    final passed = results.where((r) => r.passed).length;
    final rows = StringBuffer();
    for (final r in results) {
      final status = r.outcome == TestOutcome.passed
          ? (r.flaky ? 'FLAKY' : 'PASS')
          : (r.outcome == TestOutcome.timedOut ? 'TIMEOUT' : 'FAIL');
      final color = r.passed ? (r.flaky ? '#c69a24' : '#3f8f6b') : '#c1362f';
      rows.writeln('<tr>'
          '<td style="color:$color;font-weight:700">$status</td>'
          '<td>${_text(r.test.name)}</td>'
          '<td>${r.duration.inMilliseconds}ms</td>'
          '<td>${r.attempts}</td>'
          '<td>${r.failedStep != null ? _text(r.failedStep!.description) : ''}</td>'
          '</tr>');
    }
    return '<!doctype html><html><head><meta charset="utf-8"><title>${_text(title)}</title>'
        '<style>body{font-family:sans-serif;margin:24px}table{border-collapse:collapse;width:100%}'
        'th,td{border:1px solid #ddd;padding:8px;text-align:left}th{background:#f4f6f8}</style></head>'
        '<body><h1>${_text(title)}</h1>'
        '<p>$passed / ${results.length} passed</p>'
        '<table><thead><tr><th>Status</th><th>Test</th><th>Duration</th><th>Attempts</th><th>Failed step</th></tr></thead>'
        '<tbody>$rows</tbody></table></body></html>';
  }

  static String _attr(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _text(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
