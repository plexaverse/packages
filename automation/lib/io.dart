/// IO-dependent helpers for the automation package.
///
/// These use `dart:io` and are therefore NOT web-safe, so they are kept out of
/// the core `package:in_app_automation/in_app_automation.dart` library. Import this on
/// mobile / desktop / CI to persist reports and screenshots to disk:
///
/// ```dart
/// import 'package:in_app_automation/in_app_automation.dart';
/// import 'package:in_app_automation/io.dart';
///
/// await AutomationController.instance.runAllTests();
/// await TestArtifactWriter.write(TestReporter.instance.detailedResults);
/// ```
library;

export 'src/artifact_writer.dart';
