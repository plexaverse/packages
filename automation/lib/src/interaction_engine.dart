import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class AutomationEngine {
  static final AutomationEngine instance = AutomationEngine._();
  AutomationEngine._();

  /// Callback for when an interaction occurs (used for UI highlighting).
  void Function(Offset position)? onInteraction;

  /// Finds the first RenderBox associated with a Key.
  RenderBox? findRenderBoxByKey(Key key) {
    Element? element;
    void visitor(Element e) {
      if (e.widget.key == key) {
        element = e;
        return;
      }
      e.visitChildren(visitor);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visitor);
    
    if (element != null) {
      return element!.renderObject as RenderBox?;
    }
    return null;
  }

  /// Triggers a tap on the widget with the given Key.
  Future<void> tap(Key key) async {
    final renderBox = findRenderBoxByKey(key);
    if (renderBox == null) {
      throw Exception('Widget with key $key not found');
    }

    // Calculate center position for the highlight
    final position = renderBox.localToGlobal(
      renderBox.size.center(Offset.zero),
    );

    // Trigger visual highlight call
    onInteraction?.call(position);

    // Give some time for the highlight to show before the "tap"
    await Future.delayed(const Duration(milliseconds: 300));

    // Find the element again to get the widget
    Element? element;
    void visitor(Element e) {
      if (e.widget.key == key) {
        element = e;
        return;
      }
      e.visitChildren(visitor);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visitor);

    if (element == null) return;

    final widget = element!.widget;
    
    if (widget is FloatingActionButton) {
      widget.onPressed?.call();
    } else if (widget is ElevatedButton) {
      widget.onPressed?.call();
    } else if (widget is IconButton) {
      widget.onPressed?.call();
    } else if (widget is GestureDetector) {
      widget.onTap?.call();
    } else if (widget is InkWell) {
      widget.onTap?.call();
    }
  }

  /// Enters text into a TextField with the given Key.
  Future<void> enterText(Key key, String text) async {
    final renderBox = findRenderBoxByKey(key);
    if (renderBox == null) throw Exception('TextField with key $key not found');

    final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    onInteraction?.call(position);
    await Future.delayed(const Duration(milliseconds: 300));

    Element? element;
    void visitor(Element e) {
      if (e.widget.key == key) {
        element = e;
        return;
      }
      e.visitChildren(visitor);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visitor);

    if (element == null) return;

    final widget = element!.widget;
    if (widget is TextField) {
      widget.controller?.text = text;
      // Trigger onChanged manually if controller isn't enough for some listeners
      widget.onChanged?.call(text);
    } else if (widget is TextFormField) {
      widget.controller?.text = text;
      widget.onChanged?.call(text);
    } else {
      throw Exception('Widget with key $key is not a TextField');
    }
  }

  /// Waits for a widget with the given key to appear.
  Future<void> waitForWidget(Key key, {Duration timeout = const Duration(seconds: 5)}) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (findRenderBoxByKey(key) != null) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw Exception('Timed out waiting for widget with key $key');
  }
}
