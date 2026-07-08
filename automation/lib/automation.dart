import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'src/inspector_ui.dart';

export 'src/test_registry.dart';
export 'src/interaction_engine.dart';
export 'src/finders.dart';
export 'src/expect.dart';
export 'src/reporter.dart';
export 'src/controller.dart';
export 'src/errors.dart';
export 'src/runner.dart';
export 'src/config.dart';
export 'src/report.dart';

/// A wrapper widget that adds the Realtime Inspector overlay to the app.
class AutomationInspectorWrapper extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const AutomationInspectorWrapper({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !enabled) return child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          const Positioned.fill(
            child: AutomationInspectorOverlay(),
          ),
        ],
      ),
    );
  }
}
