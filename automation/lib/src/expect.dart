import 'package:flutter/material.dart';
import 'errors.dart';
import 'interaction_engine.dart';

/// Provides assertion methods to verify UI state during tests.
class Expect {
  const Expect._();

  /// Verifies that the [target] widget is present **and actually visible**
  /// (attached, sized, on-screen, and not clipped away by a scroll viewport).
  ///
  /// Polls every 200ms until the target becomes visible or [timeout] elapses.
  /// The failure message distinguishes "never found" from "found but not
  /// visible" so the cause is clear.
  static Future<void> visible(dynamic target, {Duration timeout = const Duration(seconds: 5)}) async {
    final engine = AutomationEngine.instance;
    final finder = engine.toFinderPublic(target);
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final element = engine.findFirstElementPublic(finder);
      if (element != null && engine.isVisiblePublic(element)) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final element = engine.findFirstElementPublic(finder);
    if (element == null) {
      throw AutomationAssertionException('Expected $target to be visible, but no matching widget was found within $timeout.');
    }
    throw AutomationAssertionException('Expected $target to be visible, but the matching widget was off-screen or clipped after $timeout.');
  }

  /// Verifies that the [target] widget is NOT visible on the screen right now.
  ///
  /// This is an immediate check (after a short frame-settle delay), not a
  /// wait-until-absent.
  static Future<void> absent(dynamic target) async {
    // Allow a tiny delay so the frame is clean, but this is an immediate check.
    await Future.delayed(const Duration(milliseconds: 50));

    final engine = AutomationEngine.instance;
    final finder = engine.toFinderPublic(target);
    final element = engine.findFirstElementPublic(finder);

    if (element != null && engine.isVisiblePublic(element)) {
      throw AutomationAssertionException('Expected $target to be absent, but it is visible.');
    }
  }

  /// Verifies that the [target] widget contains the exact [text].
  static Future<void> text(dynamic target, String text) async {
    await visible(target);
    
    final finder = AutomationEngine.instance.toFinderPublic(target);
    final element = AutomationEngine.instance.findFirstElementPublic(finder);
    
    if (element == null) throw AutomationAssertionException('Widget $target not found during text assertion.');

    final widget = element.widget;
    String? actualText;

    if (widget is Text) {
      actualText = widget.data;
    } else if (widget is RichText) {
      actualText = widget.text.toPlainText();
    } else if (widget is EditableText) {
      actualText = widget.controller.text;
    } else if (widget is TextField) {
      actualText = widget.controller?.text;
    } else if (widget is TextFormField) {
      actualText = widget.controller?.text ?? widget.initialValue;
    }
    
    // Fallback: try looking effectively at children text? 
    // For now, strict check on the widget itself.
    
    if (actualText != text) {
      throw AutomationAssertionException('Expected widget $target to have text "$text", but found "$actualText".');
    }
  }
}
