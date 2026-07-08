import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures a PNG of the app content (excluding the automation overlay).
///
/// [AutomationInspectorWrapper] wraps the app in a [RepaintBoundary] tagged
/// with [rootKey]; [capture] rasterizes that boundary. Returns null if the
/// boundary is not mounted (e.g. automation disabled, or called too early).
class AutomationScreenshot {
  AutomationScreenshot._();

  /// Key of the [RepaintBoundary] wrapping the app content.
  static final GlobalKey rootKey = GlobalKey(debugLabel: 'automationScreenshotRoot');

  /// Rasterizes the app content to PNG bytes at [pixelRatio].
  static Future<Uint8List?> capture({double pixelRatio = 1.0}) async {
    final context = rootKey.currentContext;
    if (context == null) return null;
    final object = context.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    final image = await object.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
