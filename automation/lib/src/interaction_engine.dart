import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'finders.dart';

class AutomationEngine {
  static final AutomationEngine instance = AutomationEngine._();
  AutomationEngine._();

  /// Callback for when an interaction occurs (used for UI highlighting).
  void Function(Offset position)? onInteraction;

  /// Helper to convert dynamic target (Key or Finder) to AutomationFinder
  AutomationFinder _toFinder(dynamic target) {
    if (target is AutomationFinder) return target;
    if (target is Key) return find.byKey(target);
    if (target is String) return find.byText(target);
    if (target is IconData) return find.byIcon(target);
    if (target is Type) return find.byType(target);
    throw ArgumentError('Target must be a Key, String, IconData, Type, or AutomationFinder. Got: ${target.runtimeType}');
  }

  /// Triggers a tap on the widget identified by [target].
  Future<void> tap(dynamic target, {Duration timeout = const Duration(seconds: 5)}) async {
    final finder = _toFinder(target);
    await waitFor(finder, timeout: timeout);

    final element = _findFirstElement(finder);
    if (element == null) throw Exception('Widget not found for $finder');

    // Find tappable descendant or self
    final tappable = _findFirstDescendant(element, (e) => _isTappable(e) && _isVisible(e));
     if (tappable == null) {
      // Try to tap the element itself if visible, even if not strictly "tappable" by our definition
      if (_isVisible(element)) {
         await _highlightAndTap(element);
         return;
      }
      throw Exception('Widget found but not tappable/visible: $finder');
    }

    await _highlightAndTap(tappable);
  }

  Future<void> _highlightAndTap(Element element) async {
    final renderBox = element.renderObject as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
      onInteraction?.call(position);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _triggerTap(element.widget);
  }

  /// Enters text into a TextField identified by [target].
  Future<void> enterText(dynamic target, String text, {Duration timeout = const Duration(seconds: 5)}) async {
    final finder = _toFinder(target);
    await waitFor(finder, timeout: timeout);

    final root = _findFirstElement(finder);
    if (root == null) throw Exception('Widget not found for $finder');

    final editable = _findFirstDescendant(root, (e) => _isEditable(e) && _isVisible(e));
    if (editable == null) throw Exception('No editable widget found for $finder');

    final renderBox = editable.renderObject as RenderBox?;
     if (renderBox != null) {
      final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
      onInteraction?.call(position);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    _triggerEnterText(editable.widget, text);
  }

  /// Scrolls until the [target] is visible.
  /// 
  /// Currently supports vertical scrolling in the first found Scrollable ancestor.
  Future<void> scrollUntilVisible(dynamic target, {
    dynamic scrollable,
    double step = 300.0, 
    int maxScrolls = 20,
    Duration duration = const Duration(milliseconds: 50)
  }) async {
    final targetFinder = _toFinder(target);
    
    // Check if already visible
    if (_elementExistsAndVisible(targetFinder)) return;

    // Find scrollable
    ScrollableState? scrollState;
    if (scrollable != null) {
      final scrollableFinder = _toFinder(scrollable);
      final element = _findFirstElement(scrollableFinder);
      if (element != null) {
        scrollState = Scrollable.of(element);
      }
    } else {
      // Try to find a PrimaryScrollController or fallback to the first Scrollable in view
      // This is tricky from "outside". Let's look for any Scrollable in the tree.
      // For simplicity in this version, we require 'scrollable' or we search for the biggest ScrollView.
      // Fallback: use rootElement to find first Scrollable.
      void visitor(Element e) {
        if (scrollState != null) return;
        if (e.widget is Scrollable) {
           scrollState = (e as StatefulElement).state as ScrollableState;
        }
        e.visitChildren(visitor);
      }
      WidgetsBinding.instance.rootElement?.visitChildren(visitor);
    }
    
    if (scrollState == null) throw Exception('No Scrollable found to scroll.');

    // Scroll loop
    for (int i = 0; i < maxScrolls; i++) {
        if (_elementExistsAndVisible(targetFinder)) return;
        
        final position = scrollState.position;
        if (position.pixels >= position.maxScrollExtent) {
           // Reached bottom, maybe try scrolling UP? 
           // For now, let's assume looking DOWN.
           break;
        }

        final newPos = (position.pixels + step).clamp(position.minScrollExtent, position.maxScrollExtent);
        position.jumpTo(newPos);
        await Future.delayed(duration);
    }
    
    if (!_elementExistsAndVisible(targetFinder)) {
      throw Exception('Could not find $target after scrolling $maxScrolls times.');
    }
  }

  // --- Finders & Utils ---

  Element? _findFirstElement(AutomationFinder finder) {
    final root = WidgetsBinding.instance.rootElement!;
    return finder.findFirst(root);
  }
  
  bool _elementExistsAndVisible(AutomationFinder finder) {
    final element = _findFirstElement(finder);
    return element != null && _isVisible(element);
  }

  Future<void> waitFor(dynamic target, {Duration timeout = const Duration(seconds: 5)}) async {
    final finder = _toFinder(target);
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (_findFirstElement(finder) != null) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw Exception('Timed out waiting for $finder');
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
     // ... (Previous implementation same, just copied for completeness)
    if (widget is FloatingActionButton) widget.onPressed?.call();
    else if (widget is ElevatedButton) widget.onPressed?.call();
    else if (widget is OutlinedButton) widget.onPressed?.call();
    else if (widget is TextButton) widget.onPressed?.call();
    else if (widget is IconButton) widget.onPressed?.call();
    else if (widget is GestureDetector) widget.onTap?.call();
    else if (widget is InkWell) widget.onTap?.call();
    else if (widget is InkResponse) widget.onTap?.call();
    else if (widget is MaterialButton) widget.onPressed?.call();
  }

  bool _isEditable(Element element) {
    return element.widget is TextField || element.widget is TextFormField;
  }

  void _triggerEnterText(Widget widget, String text) {
     if (widget is TextField) {
      widget.controller?.text = text;
      widget.onChanged?.call(text);
    } else if (widget is TextFormField) {
      widget.controller?.text = text;
      widget.onChanged?.call(text);
    }
  }

  bool _isVisible(Element element) {
    final renderBox = element.renderObject as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) return false;

    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final windowSize = view.physicalSize / view.devicePixelRatio;
    final screenRect = Rect.fromLTWH(0, 0, windowSize.width, windowSize.height);
    
    final pos = renderBox.localToGlobal(Offset.zero);
    final widgetRect = Rect.fromLTWH(pos.dx, pos.dy, renderBox.size.width, renderBox.size.height);

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
    
  Future<void> pumpAndSettle({Duration duration = const Duration(milliseconds: 500)}) async {
    await Future.delayed(duration);
  }
}
