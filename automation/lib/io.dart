/// IO-dependent helpers for the automation package.
///
/// These use `dart:io` and are therefore NOT web-safe, so they are kept out of
/// the core `package:automation/automation.dart` library. Import this on
/// mobile / desktop / CI to persist reports and screenshots to disk:
///
/// ```dart
/// import 'package:automation/automation.dart';
/// import 'package:automation/io.dart';
///
/// await AutomationController.instance.runAllTests();
/// await TestArtifactWriter.write(TestReporter.instance.detailedResults);
/// ```
library;

export 'src/artifact_writer.dart';
