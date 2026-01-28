import 'package:flutter/material.dart';
import 'src/test_registry.dart';
import 'src/inspector_ui.dart';

export 'src/test_registry.dart';
export 'src/interaction_engine.dart';

/// A wrapper widget that adds the Realtime Inspector overlay to the app.
class RealtimeInspectorWrapper extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const RealtimeInspectorWrapper({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          const Positioned.fill(
            child: RealtimeInspectorOverlay(),
          ),
        ],
      ),
    );
  }
}
