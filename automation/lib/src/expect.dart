import 'package:flutter/material.dart';
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
      throw Exception('Expected $target to be visible, but no matching widget was found within $timeout.');
    }
    throw Exception('Expected $target to be visible, but the matching widget was off-screen or clipped after $timeout.');
  }

  /// Verifies that the [target] widget is NOT present on the screen.
  /// 
  /// Throws an exception if the widget IS found.
  static Future<void> absent(dynamic target) async {
    // Quick check: Look for it now.
    // NOTE: We don't wait for it to disappear usually, we check effectively "now".
    // Consuming code might want to wait, but 'absent' usually implies "it shouldn't be here".
    // If we want "wait until absent", we'd need a different method.
    
    // We'll allow a tiny delay to ensure frame is clean, but mostly immediate.
    await Future.delayed(const Duration(milliseconds: 50));
    
    try {
      // If we CAN find it (and it's visible), then it's NOT absent.
      final finder = AutomationEngine.instance.toFinderPublic(target);
      final element = AutomationEngine.instance.findFirstElementPublic(finder);
      
      if (element != null && AutomationEngine.instance.isVisiblePublic(element)) {
         throw Exception('Expected $target to be absent, but it is visible.');
      }
    } catch (e) {
       // If searching throws "not found", that's good!
       // But our internal finders return null usually.
       if (e.toString().contains('Expected')) rethrow;
    }
  }

  /// Verifies that the [target] widget contains the exact [text].
  static Future<void> text(dynamic target, String text) async {
    await visible(target);
    
    final finder = AutomationEngine.instance.toFinderPublic(target);
    final element = AutomationEngine.instance.findFirstElementPublic(finder);
    
    if (element == null) throw Exception('Widget $target not found during text assertion.');

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
      throw Exception('Expected widget $target to have text "$text", but found "$actualText"');
    }
  }
}
