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

  /// Triggers a tap on the widget with the given Key or its tappable children.
  Future<void> tap(Key key) async {
    final rootElement = _findElementByKey(key);
    if (rootElement == null) {
      throw Exception('Widget with key $key not found');
    }

    // Find the actual tappable element (could be self or a descendant)
    final tappableElement = _findFirstDescendant(rootElement, (e) => _isTappable(e) && _isVisible(e));
    if (tappableElement == null) {
      throw Exception('Widget with key $key and its children are not tappable or visible');
    }

    // Use the RenderBox of the ACTUAL tappable element for precise highlight
    final renderBox = tappableElement.renderObject as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
      onInteraction?.call(position);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _triggerTap(tappableElement.widget);
  }

  bool _isTappable(Element element) {
    final widget = element.widget;
    return widget is FloatingActionButton ||
           widget is ElevatedButton ||
           widget is OutlinedButton ||
           widget is TextButton ||
           widget is IconButton ||
           widget is GestureDetector ||
           widget is InkWell ||
           widget is InkResponse ||
           widget is MaterialButton;
  }

  void _triggerTap(Widget widget) {
    if (widget is FloatingActionButton) {
      widget.onPressed?.call();
    } else if (widget is ElevatedButton) {
      widget.onPressed?.call();
    } else if (widget is OutlinedButton) {
      widget.onPressed?.call();
    } else if (widget is TextButton) {
      widget.onPressed?.call();
    } else if (widget is IconButton) {
      widget.onPressed?.call();
    } else if (widget is GestureDetector) {
      widget.onTap?.call();
    } else if (widget is InkWell) {
      widget.onTap?.call();
    } else if (widget is InkResponse) {
      widget.onTap?.call();
    } else if (widget is MaterialButton) {
      widget.onPressed?.call();
    }
  }

  /// Enters text into a TextField with the given Key or its children.
  Future<void> enterText(Key key, String text) async {
    final rootElement = _findElementByKey(key);
    if (rootElement == null) {
      throw Exception('Widget with key $key not found');
    }

    final editableElement = _findFirstDescendant(rootElement, (e) => _isEditable(e) && _isVisible(e));
    if (editableElement == null) {
      throw Exception('Widget with key $key and its children do not contain a visible TextField');
    }

    final renderBox = editableElement.renderObject as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
      onInteraction?.call(position);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _triggerEnterText(editableElement.widget, text);
  }

  bool _isEditable(Element element) {
    final widget = element.widget;
    return widget is TextField || widget is TextFormField;
  }

  void _triggerEnterText(Widget widget, String text) {
    if (widget is TextField) {
      if (widget.controller != null) {
        widget.controller!.text = text;
      }
      widget.onChanged?.call(text);
    } else if (widget is TextFormField) {
      if (widget.controller != null) {
        widget.controller!.text = text;
      }
      widget.onChanged?.call(text);
    }
  }

  bool _isVisible(Element element) {
    final renderBox = element.renderObject as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
      return false;
    }

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    
    // Get logical screen size
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final windowSize = view.physicalSize / view.devicePixelRatio;
                       
    final screenRect = Rect.fromLTWH(0, 0, windowSize.width, windowSize.height);
    final widgetRect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

    return screenRect.overlaps(widgetRect);
  }

  Element? _findFirstDescendant(Element element, bool Function(Element) predicate) {
    if (predicate(element)) return element;
    
    Element? found;
    void visitor(Element child) {
      if (found != null) return;
      if (predicate(child)) {
        found = child;
      } else {
        child.visitChildren(visitor);
      }
    }
    element.visitChildren(visitor);
    return found;
  }

  Element? _findElementByKey(Key key) {
    Element? element;
    void visitor(Element e) {
      if (e.widget.key == key) {
        element = e;
        return;
      }
      e.visitChildren(visitor);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visitor);
    return element;
  }

  /// Finds a widget that contains the given text.
  Widget? findWidgetByText(String text) {
    Element? foundElement;
    void visitor(Element e) {
      if (foundElement != null) return;
      final widget = e.widget;
      if (widget is Text && (widget.data?.contains(text) ?? false)) {
        foundElement = e;
        return;
      }
      // RichText support
      if (widget is RichText && widget.text.toPlainText().contains(text)) {
        foundElement = e;
        return;
      }
      e.visitChildren(visitor);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visitor);
    return foundElement?.widget;
  }

  /// Waits for a widget with the given key to appear.
  Future<void> waitForWidget(Key key, {Duration timeout = const Duration(seconds: 5)}) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (_findElementByKey(key) != null) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw Exception('Timed out waiting for widget with key $key');
  }

  /// Provides a short delay to allow UI to settle.
  Future<void> pumpAndSettle({Duration duration = const Duration(milliseconds: 500)}) async {
    await Future.delayed(duration);
  }

  /// Finds a widget by its key in the widget tree.
  Widget? findWidget(Key key) {
    return _findElementByKey(key)?.widget;
  }
}
