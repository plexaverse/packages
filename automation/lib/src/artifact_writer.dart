import 'dart:io';

import 'report.dart';
import 'runner.dart';

/// Writes run artifacts to disk: a JSON, JUnit XML, and HTML report, plus a
/// PNG per failed test that captured a screenshot.
///
/// Uses `dart:io`, so it is NOT web-safe and lives behind the separate
/// `package:automation/io.dart` entrypoint rather than the core library.
class TestArtifactWriter {
  const TestArtifactWriter._();

  /// Writes reports (and any failure screenshots) into [directory], creating it
  /// if needed. Returns the absolute directory path.
  static Future<String> write(
    List<TestResult> results, {
    String directory = 'build/automation-reports',
  }) async {
    final dir = Directory(directory);
    await dir.create(recursive: true);

    await File('${dir.path}/report.json').writeAsString(TestReportFormatter.toJson(results));
    await File('${dir.path}/junit.xml').writeAsString(TestReportFormatter.toJUnitXml(results));
    await File('${dir.path}/report.html').writeAsString(TestReportFormatter.toHtml(results));

    for (final result in results) {
      final shot = result.screenshot;
      if (shot != null) {
        await File('${dir.path}/${_slug(result.test.name)}.png').writeAsBytes(shot);
      }
    }

    return dir.absolute.path;
  }

  static String _slug(String name) {
    final s = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return s.isEmpty ? 'test' : s;
  }
}
